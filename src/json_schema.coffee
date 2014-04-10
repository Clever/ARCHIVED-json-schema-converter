_ = require 'underscore'
_.mixin require 'underscore.deep'
{inspect} = require 'util'
JaySchema = require 'jayschema'
mongoose = require 'mongoose'
custom_types = require './custom_types'

_.mixin filterValues: (obj, test) -> _.object _.filter _.pairs(obj), ([k, v]) -> test v, k

# list from: https://github.com/LearnBoost/mongoose/blob/3.8.x/lib/schematype.js
# and http://mongoosejs.com/docs/api.html
#
# This is very much a hack. In mongoose, there is no way to determine if
# an object is just a subschema or is the options object of a field.
# The 'solution' is to see if there are any keys of the object which are
# NOT mongoose reserved keys- if there are only mongoose reserved keys,
# very very likely the object is just an options object
has_only_mongoose_reserved_keys = (obj) -> _.isEmpty _.difference _.keys(obj), [
  'getDefault', 'applySetters',
  'applyGetters', 'doValidate', 'type', 'ref',
  #schemaType
  'sparse', 'select', 'set', 'get', 'index', 'default',
  'unique', 'required', 'validate',
  #string
  'enum', 'match', 'lowercase', 'uppercase', 'trim',
  #date
  'expires',
  #number
  'min', 'max',
  #object
  'auto'
]

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
    type_ref_to_mongoose_type =
      objectid         : mongoose.Schema.Types.ObjectId
      date_or_datetime : Date

    convert = (json_schema) ->
      switch
        when json_schema.$ref?
          custom_name = custom_types.ref_to_id[json_schema.$ref]
          def = custom_types.id_to_def[custom_name]() if custom_name?
          unless custom_name? and def? and type_ref_to_mongoose_type[custom_name]?
            throw new Error "Unsupported $ref value: #{json_schema.$ref}"
          type_ref_to_mongoose_type[custom_name]
        # also handle incoming date or date-time formats
        when json_schema.type is 'string' and json_schema.format in ['date', 'date-time']
          type_ref_to_mongoose_type.date_or_datetime
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
      throw new Error "Invalid JSON schema, issue at: #{validate(json_schema)[0].instanceContext}" unless is_valid json_schema
      convert json_schema

  from_mongoose_schema: do ->
    # No 'integer' b/c mongoose has only a 'Number' type
    mongoose_type_to_schema =
      Number  : -> type: 'number'
      String  : -> type: 'string'
      Boolean : -> type: 'boolean'
      Date    : -> $ref: custom_types.id_to_ref['date_or_datetime']()
      ObjectId: -> $ref: custom_types.id_to_ref['objectid']()
      Mixed   : -> type: 'object' # No constraints on properties

    convert = (mongoose_fragment) ->
      switch
        when mongoose_type_to_schema[mongoose_fragment.name]?
          mongoose_type_to_schema[mongoose_fragment.name]()
        when mongoose_fragment.type? and has_only_mongoose_reserved_keys mongoose_fragment # is options obj
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
      _.extend convert(mongoose_schema), definitions: custom_types.definitions()


  spec_from_mongoose_schema: (mongoose_schema) ->
    spec_from_tree = (tree) ->
      switch
        when _.isArray tree
          _.map tree, spec_from_tree
        when tree.type? and has_only_mongoose_reserved_keys tree # is options obj
          if tree.required? then _.pick tree, ['type', 'required'] else tree.type
        when _.isPlainObject tree
          # Remove virtuals
          tree = _.filterValues tree, (subtree) -> not (subtree.getters? and subtree.setters?)
          _.mapValues tree, spec_from_tree
        else
          tree
    spec_from_tree mongoose_schema.tree
