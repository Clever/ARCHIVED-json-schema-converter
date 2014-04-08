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
    ,
      tags: [String, Number]
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
      # Non-object schemas
      json: { type: 'string' },   mongoose: String
    ,
      json: { type: 'boolean' },  mongoose: Boolean
    ,
      json: { type: 'number' },   mongoose: Number
    ,
      json: { type: 'object' },   mongoose: Schema.Types.Mixed
    ,
      json: { type: 'array' },    mongoose: []
    ,
      json: { $ref: '#/definitions/objectid' },  mongoose: Schema.Types.ObjectId
    ,
      json: { $ref: '#/definitions/date_or_datetime' },  mongoose: Date
    ,
      # Simple arrays
      json:
        type: 'array'
        items: type: 'string'
      mongoose: [String]
    ,
      # Simple objects
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
          birthday: $ref: '#/definitions/date_or_datetime'
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
      # Objects with type as field name
      json:
        type: 'object'
        properties:
          foo: type: 'number'
          type: type: 'string'
      mongoose:
        foo: Number
        type: String
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
    ,
      # Arrays and objects
      json:
        type: 'array'
        items:
          type: 'object'
          properties:
            name: type: 'string'
      mongoose: [{ name: String }]
    ,
      json:
        type: 'object'
        properties:
          tags:
            type: 'array'
            items: type: 'string'
      mongoose: tags: [String]
    ], ({json, mongoose}) ->
      ###
      The custom ref definitions need to be added to the incoming
      JSON-schema objects so that any tests can refer to it with:
        $ref: '#/definitions/objectid', etc

      We really only need to add it to the ones which reference the
      objectid, date_or_datetime definition, but this is cleaner.
      ###
      json.definitions = _.extend({}, (_.pluck custom_types, 'definition')...)

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
      ,
        json:
          type: 'object'
          properties: {}
        mongoose: Schema.Types.Mixed
        json_back:
          type: 'object'
      ,
        # Mongoose doesn't have a way to specify if a field that contains
        # nested fields is required or not. So this case is weird...
        json:
          type: 'object'
          properties:
            name:
              type: 'object'
              properties:
                first: type: 'string'
          required: ['name']
        mongoose:
          name:
            first: String
        json_back:
          type: 'object'
          properties:
            name:
              type: 'object'
              properties:
                first: type: 'string'
      ,
        json:
          type: 'object'
          properties:
            birthday:
              type: 'string'
              format: 'date'
        mongoose:
          birthday: Date
        json_back:
          type: 'object'
          properties:
            birthday: $ref: "#/definitions/date_or_datetime"
      ,
        json:
          type: 'object'
          properties:
            birthday:
              type: 'string'
              format: 'date-time'
        mongoose:
          birthday: Date
        json_back:
          type: 'object'
          properties:
            birthday: $ref: "#/definitions/date_or_datetime"
    ], ({json, mongoose, json_back}) ->

      json.definitions = _.extend({}, (_.pluck custom_types, 'definition')...)
      json_back.definitions = json.definitions

      it ".to_mongoose converts #{inspect json}", ->
        assert.deepEqual json_schema.to_mongoose_schema(json), mongoose
      it ".from_mongoose converts #{inspect mongoose}", ->
        assert.deepEqual json_schema.from_mongoose_schema(mongoose), json_back

  describe 'tests that from_mongoose adds custom_types', ->
    basic_mongoose = foo: String
    basic_json =
      definitions:
        objectid: custom_types.objectid.definition.objectid
        date_or_datetime: custom_types.date_or_datetime.definition.date_or_datetime
      type: 'object'
      properties: foo: type: 'string'
    it 'from_mongoose creates the correct custom types', ->
      assert.deepEqual json_schema.from_mongoose_schema(basic_mongoose), basic_json


  describe '.spec_from_mongoose_schema', ->
    _.each [
      spec: name: String
      expected: null # same as spec
    ,
      spec: name: { type: String, default: 'Pluto' }
      expected: name: String
    ,
      spec: name: String, age: Number
      expected: null # same as spec
    ,
      spec:
        name:
          first: String
          last: String
        age: Number
      expected: null # same as spec
    ,
      spec: name: first: { type: String, default: 'Pluto' }
      expected: name: first: String
    ,
      spec: tags: [String]
      expected: null # same as spec
    ,
      spec: comments: [{ body: String }]
      expected: null # same as spec
    ,
      spec: sister: Schema.Types.ObjectId
      expected: null # same as spec
    ,
      spec: sister: { type: Schema.Types.ObjectId, ref: 'Person' }
      expected: sister: Schema.Types.ObjectId
    ,
      spec: name: { type: String, required: true }
      expected: null # same as spec
    ,
      spec: name: first: { type: String, required: true }
      expected: null # same as spec
    ,
      spec:
        created:
          index: true
          required: true
          type: Date
        type:
          index: true
          required: true
          type: String
        required:
          type: Boolean
      expected:
        type: { type: String, required: true }
        created: { type: Date, required: true }
        required: Boolean
    ,
      spec:
        foo: type: String
        type:
          first: type: String
          type: type: String
          required: type: String
      expected:
        foo: String
        type:
          first: String
          type: String
          required: String
    ,
      spec: type: first: String
      expected: type: first: String
    ], ({spec, expected}) ->
      expected ?= spec
      it "extracts spec from schema #{inspect spec}", ->
        assert.deepEqual json_schema.spec_from_mongoose_schema(new Schema spec),
          _.extend expected, _id: Schema.Types.ObjectId
