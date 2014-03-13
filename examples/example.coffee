{inspect} = require 'util'
mongoose = require 'mongoose'
jsc = require '../src/json_schema'
json_person = require './js_person.json'
{mongoose_movie} = require './ms_movie'

# JSON Schema to Mongoose Schema
console.log "Incoming JSON schema: #{inspect json_person}"
console.log "Valid? #{jsc.is_valid json_person}"
mongoose_person_schema = new mongoose.Schema jsc.to_mongoose_schema(json_person)
console.log "mongoose schema output: #{inspect mongoose_person_schema}"

Person = mongoose.model 'Person', mongoose_person_schema
console.log "mongoose person instance: #{inspect Person}"
bill_gates = new Person {name:"Bill Gates", emp_id:1, birthday:"1955-10-28", favorite_things: color: 'beige'}
console.log "this could be saved to mongo: #{inspect bill_gates}"

console.log "-------------------------------------"

# Mongoose Schema to JSON Schema
console.log "Incoming mongoose schema: #{inspect mongoose_movie}"
json_schema_movie = jsc.from_mongoose_schema mongoose_movie
console.log "JSON Schema movie: #{inspect json_schema_movie}"
console.log "Valid? #{jsc.is_valid json_schema_movie}"

