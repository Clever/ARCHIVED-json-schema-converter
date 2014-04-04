_ = require 'underscore'
_.mixin require 'underscore.deep'
{inspect} = require 'util'
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
        when type_string_to_mongoose_type[json_schema.type]?
          type_string_to_mongoose_type[json_schema.type]
        when json_schema.type is 'object'
          if not json_schema.properties? or _.isEmpty json_schema.properties
            mongoose.Schema.Types.Mixed
          else
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
        when json_schema.type is 'array'
          if json_schema.items? then [convert json_schema.items] else []
        else
          throw new Error "Unsupported JSON schema type #{json_schema.type}"

    (json_schema) ->
      throw new Error 'Invalid JSON schema' unless is_valid json_schema
      convert json_schema

  from_mongoose_schema: do ->
    # No 'integer' b/c mongoose has only a 'Number' type
    mongoose_type_to_schema =
      Number  : -> type: 'number'
      String  : -> type: 'string'
      Boolean : -> type: 'boolean'
      Date    : -> type: 'string', format: 'date-time'
      ObjectId: -> $ref: custom_types.objectid.ref
      Mixed   : -> type: 'object' # No constraints on properties

    convert = (mongoose_fragment) ->
      switch
        when mongoose_type_to_schema[mongoose_fragment.name]?
          mongoose_type_to_schema[mongoose_fragment.name]()
        when mongoose_fragment.type?
          convert mongoose_fragment.type
        when _.isPlainObject mongoose_fragment
          required = _.keys _.filterValues mongoose_fragment, (subfragment) -> subfragment.required
          _.extend
            type: 'object'
            properties: _.mapValues mongoose_fragment, convert
            if _.isEmpty required then {} else {required}
        when _.isArray mongoose_fragment
          switch mongoose_fragment.length
            when 0 then type: 'array'
            when 1 then type: 'array', items: convert mongoose_fragment[0]
            else throw new Error "Invalid mongoose schema: array can't contain more than one subschema"
        else
          throw new Error "Unsupported mongoose schema type #{inspect mongoose_fragment}"

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
