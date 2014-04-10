_ = require 'underscore'
hour = '(0[0-9]|1[0-9]|2[0-3])'
min_or_sec = '(:[0-5][0-9])'

# need to use #{' '} b/c json-schema pattern also does not understand '\s'
# coffeescript concatenates the whitespace before interpolation
DATE_OR_DATETIME_REGEX = ///     #          req?
  ^ [0-9]{4}                     # year      Y
  ([-/.](0[1-9]|1[012])          # month     Y
  ([-/.](0[1-9]|[12][0-9]|3[01]) # day       Y
      ([Tt#{' '}]                # sep       Y, if TZ
        ( #{hour}                # hour 00   N
          #{min_or_sec}?         # min :00   N
          #{min_or_sec}?         # sec :00   N
        )?                       #           -
        (                        #           -
          [zZ]                   # Zz        N
          | ( [-+]               # -/+       Y, if TZ
              #{hour}            # hour off  Y, if TZ
              #{min_or_sec}?     # min off   N
            )?
        )?
      )?
    )?
  )? $
///

OBJECT_ID_REGEX = /^[0-9a-fA-F]{24}$/

mappings =
  objectid:
    ref: "#/definitions/objectid"
    def: objectid: { type: 'string', pattern: OBJECT_ID_REGEX.toString()[1..-2] }
    pattern: OBJECT_ID_REGEX
  date_or_datetime:
    ref: "#/definitions/date_or_datetime"
    def: date_or_datetime: { type: 'string', pattern: DATE_OR_DATETIME_REGEX.toString()[1..-2] }
    pattern: DATE_OR_DATETIME_REGEX

# do this complicated mapping with functions to protect
# the objects from being munged by library users
module.exports =
  id_to_ref: _.object _.keys(mappings), _.map _.pluck(mappings, 'ref'), (v) -> (-> v)
  id_to_def: _.object _.keys(mappings), _.map _.pluck(mappings, 'def'), (v) -> (-> v)
  id_to_pattern: _.object _.keys(mappings), _.map _.pluck(mappings, 'pattern'), (v) -> (-> v)

  ref_to_id: _.object _.pluck(mappings, 'ref'), _.keys mappings
  definitions: ( -> _.extend {},  _.pluck(mappings, 'def')...)
