assert = require 'assert'
_ = require 'underscore'
_.mixin require 'underscore.deep'
{Schema} = require 'mongoose'
{inspect} = require 'util'
json_schema = require '../lib/json_schema'
custom_types = require '../lib/custom_types'

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
    ], ({json, mongoose, json_back}) ->
      json.definitions = custom_types.objectid.definition
      json_back.definitions = custom_types.objectid.definition

      it "to mongoose not symmetric succeeds: #{inspect json}", ->
        assert.deepEqual json_schema.to_mongoose_schema(json), mongoose
      it "from mongoose not symmetric succeeds: #{inspect mongoose}", ->
        assert.deepEqual json_schema.from_mongoose_schema(mongoose), json_back

  describe '.to_update_schema', ->
    # TODO
    # - schema types (http://mongoosejs.com/docs/schematypes.html)
    #   x String
    #   x Number
    #   - Date
    #   - Buffer?
    #   - Boolean
    #   - Mixed
    #   - ObjectId
    #   - Array
    # - Allow nested update objects as well as dot-notation paths
    # - Support update operators

    schemas =
      one_field:
        model:
          type: 'object'
          additionalProperties: false
          properties:
            name: type: 'string'
        update: null # same as model
        valid_queries: [
          { name: 'harry' }
        ]
        invalid_queries: [
          { name: 1 }
          { name: 'harry', not_in_schema: 'sally' }
        ]

      two_field:
        model:
          type: 'object'
          additionalProperties: false
          properties:
            name: type: 'string'
            age: type: 'number'
        update: null # same as model
        valid_queries: [
          { name: 'harry' }
          { age: 10 }
          { name: 'sally', age: 8 }
        ]
        invalid_queries: [
          { name: 1 }
          { name: 'harry', not_in_schema: 'sally' }
          { age: '1' }
          { name: 'harry', age: 'sally' }
        ]

      nested:
        model:
          type: 'object'
          additionalProperties: false
          properties:
            name:
              type: 'object'
              properties:
                first: type: 'string'
                last: type: 'string'
        update:
          type: 'object'
          additionalProperties: false
          properties:
            'name.first': type: 'string'
            'name.last': type: 'string'
        valid_queries: [
          { 'name.first': 'harry' }
          { 'name.last': 'burns' }
          { 'name.first': 'sally', 'name.last': 'albright' }
        ]
        invalid_queries: [
          { name: 1 }
          { 'name.first': 2 }
          { 'name.last': 3 }
          { name: { first: 'sally', last: 'albright' }} # TODO support these maybe?
          { 'name.first': 'harry', not_in_schema: 'burns' }
        ]


    _.each schemas, ({model, update, valid_queries, invalid_queries}, name) ->
      update ?= model
      describe inspect(update), ->
        before ->
          errs = json_schema.validate update
          assert _.isEmpty(errs), "Expected update schema isn\'t a valid json schema
            whoever wrote the test messed up: #{inspect errs}"

        it "converts from #{inspect model}", ->
          assert.deepEqual json_schema.to_update_schema(model), update

        always_valid_queries = [{}]
        _.each always_valid_queries.concat(valid_queries), (query) ->
          it "allows query #{inspect query}", ->
            errs = json_schema.validate query, update
            assert _.isEmpty(errs), "Expected no errors, got: #{inspect errs}"

        always_invalid_queries = [{ not_in_schema: 'nope' }]
        _.each always_invalid_queries.concat(invalid_queries), (query) ->
          it "rejects query #{inspect query}", ->
            errs = json_schema.validate query, update
            assert not _.isEmpty(errs), 'Expected errors'
