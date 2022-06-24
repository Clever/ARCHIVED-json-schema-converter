# Notice

_ARCHIVED: This repo is no longer maintained by Clever._

# JSON Schema Converter

A translation and validation library between [JSON Schema](http://json-schema.org/) and any other schema.

Don't get locked into your database schema forever- make sure you can always
use the latest, <del>most buggy</del> most trendy database with minimal work.

With the JSON Schema converter, you can also validate your schemas. No
matter what db client you're using, you can be confident a schema matches
what the client expects.

###Currently supported:
- [mongoose schema](http://mongoosejs.com/)

## Installation

    npm install json-schema-converter

## Usage

```coffee
{inspect} = require 'util'
json_schema = require 'json-schema-converter'
your_schema = require 'your_schema.json'

# to make sure - validate returns a structure that describes the error
unless json_schema.is_valid your_schema
  throw new Error "JSON Schema is invalid, error is: #{inspect json_schema.validate(your_schema)}"

# the actual conversion
your_mongoose_schema = json_schema.to_mongoose_schema your_schema

# now instantiate
your_mongoose_object = new mongoose.Schema your_mongoose_schema

# and you're on your way...
# want to convert back? See the examples!
```

See [the examples](examples) for usage.


## Future Path

Right now we only support Mongoose schemas, but we hope to translate
any schema to JSON schema and back as effortlessly as possible.
