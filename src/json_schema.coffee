_ = require 'underscore'
_.mixin require 'underscore.deep'
JaySchema = require 'jayschema'
mongoose = require 'mongoose'
custom_types = require './custom_types'

_.mixin filterValues: (obj, test) -> _.object _.filter _.pairs(obj), ([k, v]) -> test v, k

module.exports =
  # Validate an object against a schema.
  # If given just a schema, validates it against the JSON schema meta-schema
  # JaySchema references the meta-schema by its url even though it is bundled
  # locally in the library (http://json-schema.org)
  validate: validate = do ->
    validator = new JaySchema()
    (instance, schema='http://json-schema.org/draft-04/schema#') ->
      validator.validate instance, schema

  is_valid: is_valid = _.compose _.isEmpty, validate

  to_mongoose_schema: do ->
    type_string_to_mongoose_type =
      'string'  : String
      'boolean' : Boolean
      'number'  : Number
      'integer' : Number

    convert = (json_schema) ->
      switch
        when json_schema.$ref?
          if json_schema.$ref not in _.pluck custom_types, 'ref'
            throw new Error "Unsupported $ref value: #{json_schema.$ref}"
          mongoose.Schema.Types.ObjectId
        when json_schema.type is 'string' and json_schema.format is 'date-time'
          Date
        when json_schema.type of type_string_to_mongoose_type
          type_string_to_mongoose_type[json_schema.type]
        when json_schema.type is 'object'
          converted = _.mapValues json_schema.properties, convert
          if json_schema.required?
            _.mapValues converted, (subschema, key) ->
              if key in json_schema.required and not _.isPlainObject subschema
                type: subschema
                required: true
              else
                subschema
          else
            converted
        else
          throw new Error "Unsupported JSON schema type #{json_schema.type}"

    (json_schema) ->
      throw new Error 'Invalid JSON schema' unless is_valid json_schema
      convert json_schema

  from_mongoose_schema: do ->
    # no 'integer' b/c mongoose has only a 'Number' type
    mongoose_type_to_type_string =
      String  : 'string'
      Boolean : 'boolean'
      Number  : 'number'

    convert = (mongoose_fragment) ->
      # figure out type and properties
      switch
        when mongoose_fragment is undefined
          {}
        when mongoose_fragment.name is 'Date'
          type:'string'
          format: 'date-time'
        when mongoose_fragment.name is 'ObjectId'
          $ref: custom_types.objectid.ref
        when mongoose_fragment.name of mongoose_type_to_type_string
          type: mongoose_type_to_type_string[mongoose_fragment.name]
        when mongoose_fragment.type?
          convert mongoose_fragment.type
        when _.isPlainObject mongoose_fragment
          required = _.keys _.filterValues mongoose_fragment, (subfragment) -> subfragment.required
          _.extend
            type: 'object'
            properties: _.mapValues mongoose_fragment, convert
            unless _.isEmpty required then {required} else {}
        else
          throw new Error "Unsupported mongoose schema type #{mongoose_fragment}"

    (mongoose_schema) ->
      try
        new mongoose.Schema mongoose_schema
      catch error
        throw new Error "Invalid mongoose schema: '#{mongoose_schema}', err is: #{error.message}"
      # Really, we only need to add the ObjectId type definition to those schemas
      # which include a $ref to object id, but for now we can just append to all
      # JSON Schemas- not a big deal.
      _.extend convert(mongoose_schema), definitions: custom_types.objectid.definition

  spec_from_mongoose_schema: (mongoose_schema) ->
    spec_from_tree = (tree) ->
      switch
        when _.isArray tree
          _.map tree, spec_from_tree
        when tree.type? and tree.required?
          _.pick tree, ['type', 'required']
        when tree.type?
          tree.type
        when _.isPlainObject tree
          # Remove virtuals
          tree = _.filterValues tree, (subtree) -> not (subtree.getters? and subtree.setters?)
          _.mapValues tree, spec_from_tree
        else
          tree
    spec_from_tree mongoose_schema.tree
