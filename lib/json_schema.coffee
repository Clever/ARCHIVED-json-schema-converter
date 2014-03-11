_ = require 'underscore'
_.mixin require 'underscore.deep'
JaySchema = require 'jayschema'
mongoose = require 'mongoose'
custom_types = require './custom_types'

_.mixin concatMap: (args...) -> _.flatten _.map(args...), true

module.exports =
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
          _.mapValues json_schema.properties, convert
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
        when _.isObject mongoose_fragment
          type: 'object'
          properties: _.mapValues mongoose_fragment, convert
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

  # Validate an object against a schema.
  # If given just a schema, validates it against the JSON schema meta-schema
  # JaySchema references the meta-schema by its url even though it is bundled
  # locally in the library (http://json-schema.org)
  validate: validate = do ->
    validator = new JaySchema()
    (instance, schema='http://json-schema.org/draft-04/schema#') ->
      validator.validate instance, schema

  is_valid: is_valid = _.compose _.isEmpty, validate

  # Turns a schema representing a deeply nested object into a schema
  # representing the dot-notation version of that object.
  # This is a lossy conversion - any data on nested schemas besides the
  # 'properties' object will be lost.
  deep_to_flat: deep_to_flat = do ->
    deep_to_flat_helper = (object_schema) ->
      _.object _.concatMap object_schema.properties, (subschema, key) ->
        if subschema.type is 'object'
          _.map deep_to_flat_helper(subschema), (val, subkey) -> ["#{key}.#{subkey}", val]
        else
          [[key, subschema]]
    (schema) ->
      if schema.type is 'object'
        deep_to_flat_helper schema
      else schema

  # Converts a JSON schema representing a Mongo model into a JSON schema for a
  # valid update query object against that model.
  to_update_schema: do ->
    # For now, don't allow any update operators, just allow simple field/val
    # pairs of the proper type.
    simple_schema_to_update_schema = (schema) -> schema
    (model_schema) ->
      switch model_schema.type
        when 'string', 'number' then simple_schema_to_update_schema model_schema
        when 'object'
          _.extend _.pick(model_schema, ['type', 'additionalProperties']),
            properties: _.mapValues deep_to_flat(model_schema), simple_schema_to_update_schema
        else throw new Error "Unsupported model schema type #{model_schema.type}"
