assert = require 'assert'
_ = require 'underscore'
_.mixin require 'underscore.deep'
{Schema} = require 'mongoose'
{inspect} = require 'util'
json_schema = require '../src/json_schema'
custom_types = require '../src/custom_types'

describe 'mongoose schema conversion:', ->
  describe '.to_mongoose_schema', ->
    _.each [
      type: 'objectttttt'
    ,
      type: 'object'
      properties: 'not an object'
    ,
      type: 'object',
      properties:
        email: type: 'not a type'
    ], (invalid) ->
      it "throws on invalid json schema #{inspect invalid}", ->
        assert.throws (-> json_schema.to_mongoose_schema invalid), /Invalid JSON schema/

    _.each [
      type: 'object'
      properties:
        id: $ref: '#/nope/nope/nope'
    ], (invalid) ->
      it "throws on unsupported ref #{inspect invalid}", ->
        assert.throws (-> json_schema.to_mongoose_schema invalid), /Unsupported .ref/

  describe '.from_mongoose_schema', ->
    _.each [
      foo: "bar"
    ], (invalid) ->
      it "throws on invalid mongoose schema #{inspect invalid}", ->
        assert.throws (-> json_schema.from_mongoose_schema invalid), /Invalid mongoose schema/

    _.each [
      mongoose: 'Mixed'
    ], (invalid) ->
      it "throws on unsupported mongoose schema type #{inspect invalid}", ->
        assert.throws (-> json_schema.from_mongoose_schema invalid), /Unsupported mongoose schema type/

  describe 'symmetric conversion:', ->
    _.each [
      json: { type: 'string' },  mongoose: String
    ,
      json: { type: 'boolean' }, mongoose: Boolean
    ,
      json: { type: 'number' },  mongoose: Number
    ,
      json: { type: 'string', format: 'date-time' },  mongoose: Date
    ,
      json: { $ref: '#/definitions/objectid' },  mongoose: Schema.Types.ObjectId
    ,
      json:
        type: 'object'
        properties: {}
      mongoose: {}
    ,
      json:
        type: 'object'
        properties: email: type: 'string'
      mongoose: { email: String }
    ,
      json:
        type: 'object'
        properties:
          email: type: 'string'
          age: type: 'number'
          birthday: type: 'string', format:'date-time'
          oid: $ref: '#/definitions/objectid'
      mongoose:
        email: String
        age: Number
        birthday: Date
        oid: Schema.Types.ObjectId
    ,
      json:
        type: 'object'
        properties:
          name:
            type: 'object'
            properties:
              first: type: 'string'
              last: type: 'string'
      mongoose:
        name:
          first: String
          last: String
    ], ({json, mongoose}) ->
      ###
      The objectid ref definition needs to be added to the incoming
      JSON-schema objects so that any tests can refer to it with:
        $ref: '#/definitions/objectid'

      We really only need to add it to the ones which reference, the
      objectid definition, but this is cleaner.
      ###
      json.definitions = custom_types.objectid.definition

      it ".to_mongoose converts #{inspect json}", ->
        assert.deepEqual json_schema.to_mongoose_schema(json), mongoose
      it ".from_mongoose converts #{inspect mongoose}", ->
        assert.deepEqual json_schema.from_mongoose_schema(mongoose), json

  describe 'asymmetric conversion:', ->
    _.each [
        json: { type: 'integer' }, mongoose: Number, json_back: type: 'number'
      ,
        json:
          type: 'object'
          properties:
            age: type: 'integer'
        mongoose:
          age: Number
        json_back:
          type: 'object'
          properties:
            age: type: 'number'
    ], ({json, mongoose, json_back}) ->
      json.definitions = custom_types.objectid.definition
      json_back.definitions = custom_types.objectid.definition

      it ".to_mongoose converts #{inspect json}", ->
        assert.deepEqual json_schema.to_mongoose_schema(json), mongoose
      it ".from_mongoose converts #{inspect mongoose}", ->
        assert.deepEqual json_schema.from_mongoose_schema(mongoose), json_back
