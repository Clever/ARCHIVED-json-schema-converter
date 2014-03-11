js = require '../lib/json_schema'
{inspect} = require 'util'
mongoose = require 'mongoose'
person = require './person.json'

mongoose_person_schema = js.to_mongoose_schema person
console.log "mongoose schema input: #{inspect mongoose_person_schema}"

# the real test is instantiation
mongoose_object = new mongoose.Schema mongoose_person_schema
console.log "mongoose person instance: #{inspect mongoose_object}"
