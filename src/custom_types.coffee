day = '([-/.](0[1-9]|[12][0-9]|3[01]))'
month = '([-/.](0[1-9]|1[012]))'
hour = '(0[0-9]|1[0-9]|2[0-3])'
min_or_sec = '(:[0-5][0-9])'
tz = "([zZ]|([-+]#{hour}#{min_or_sec}?)?)"

module.exports =
  objectid:
    ref: "#/definitions/objectid"
    definition: objectid: { type: 'string', pattern: '^[0-9a-fA-F]{24}$' }
  date_or_datetime:
    ref: "#/definitions/date_or_datetime"
    definition: date_or_datetime: { type: 'string', pattern: "^[0-9]{4}(#{month}(#{day}([Tt ](#{hour}#{min_or_sec})?(#{min_or_sec}?(([-+]#{min_or_sec})?#{min_or_sec}?#{tz}?)?)?)?)?)?$" }
