assert = require 'assert'
_ = require 'underscore'
_.mixin require 'underscore.deep'
{Schema} = require 'mongoose'
{inspect} = require 'util'
json_schema = require '../src/json_schema'
custom_types = require '../src/custom_types'

assert.deepEqual = do ->
  orig_deepEqual = assert.deepEqual
  (actual, expected) ->
    orig_deepEqual actual, expected, "#{inspect actual, depth: null}\n!=\n#{inspect expected, depth: null}"

describe 'json_schema', ->
  describe 'mongoose schema conversion', ->
    describe 'invalid json', ->
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
        it "throws on invalid schema #{inspect invalid}", ->
          assert.throws (-> json_schema.to_mongoose_schema invalid), /Invalid JSON schema/

    describe 'invalid mongoose schema', ->
      _.each [
        foo: "bar"
      ], (invalid) ->
        it "throws invalid mongoose schema #{inspect invalid}", ->
          assert.throws (-> json_schema.from_mongoose_schema invalid), /Invalid mongoose schema/

    describe 'unsupported $ref', ->
      _.each [
        type: 'object'
        properties:
          id: $ref: '#/nope/nope/nope'
      ], (invalid) ->
        it "throws on unsupported ref #{inspect invalid}", ->
          assert.throws (-> json_schema.to_mongoose_schema invalid), /Unsupported .ref/

    describe 'unsupported mongoose schema type', ->
      _.each [
        mongoose: 'Mixed'
      ], (invalid) ->
        it "throws unsupported mongoose #{inspect invalid}", ->
          assert.throws (-> json_schema.from_mongoose_schema invalid), /Unsupported mongoose schema type/

    describe 'symmetric tests', ->
      _.each [
        # Non-object schemas
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
        # Simple objects
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
        # Objects with nested fields
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
      ,
        # Objects with required fields
        json:
          type: 'object'
          properties:
            name: type: 'string'
            email: type: 'string'
            age: type: 'number'
          required: ['name', 'age']
        mongoose:
          name: type: String, required: true
          email: String
          age: type: Number, required: true
      ,
        json:
          type: 'object'
          properties:
            name:
              type: 'object'
              properties:
                first: type: 'string'
                last: type: 'string'
              required: ['first']
        mongoose:
          name:
            first: type: String, required: true
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

        it "to mongoose succeeds: #{inspect json}", ->
          assert.deepEqual json_schema.to_mongoose_schema(json), mongoose
        it "from mongoose succeeds: #{inspect mongoose}", ->
          assert.deepEqual json_schema.from_mongoose_schema(mongoose), json

  describe 'asymmetric tests', ->
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
      ,
        # Mongoose doesn't have a way to specify if a field that contains
        # nested fields is required or not. So this case is weird...
        json:
          type: 'object'
          properties:
            name:
              type: 'object'
              properties: {}
          required: ['name']
        mongoose:
          name: {}
        json_back:
          type: 'object'
          properties:
            name:
              type: 'object'
              properties: {}
    ], ({json, mongoose, json_back}) ->
      json.definitions = custom_types.objectid.definition
      json_back.definitions = custom_types.objectid.definition

      it "to mongoose not symmetric succeeds: #{inspect json}", ->
        assert.deepEqual json_schema.to_mongoose_schema(json), mongoose
      it "from mongoose not symmetric succeeds: #{inspect mongoose}", ->
        assert.deepEqual json_schema.from_mongoose_schema(mongoose), json_back
