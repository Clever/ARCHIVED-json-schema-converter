{Schema} = require 'mongoose'

module.exports =
  mongoose_movie:
    "name": String,
    "date_released": Date,
    "id": Schema.Types.ObjectId
