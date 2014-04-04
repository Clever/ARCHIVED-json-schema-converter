
module.exports =
  # full regex is really gross:
  # http://www.pelagodesign.com/blog/2009/05/20/iso-8601-date-validation-that-doesnt-suck/
  # going with this right now, bare minimum that we want to support.
  # this allows 2010-02-18T16:23.33+0600, etc, anything that Date can construct from
  js_simple_date_regex: js_simple_date_regex = '^[0-9]{4}[-/.][0-9]{2}[-/.][0-9]{2}'
