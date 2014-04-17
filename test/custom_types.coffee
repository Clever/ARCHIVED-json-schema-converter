_ = require 'underscore'
assert = require 'assert'
{inspect} = require 'util'
custom_types = require '../src/custom_types'

describe 'date regex tests:', ->
  date_regex = new RegExp custom_types.date_or_datetime.pattern
  # all examples are from:
  # http://www.pelagodesign.com/blog/2009/05/20/iso-8601-date-validation-that-doesnt-suck/
  _.each [
    '2009'
    '2009-05'
    '2009-05-19'
    '2009-05-19 00:00'
    '2009-05-19 14:31'
    '2009-05-19 14:39:22'
    '2009-05-19T14:39Z'
    '2009-05-19 14:39:22-06:00'
    '2009-05-19 14:39:22-01'
    '2007-04-06T00:00'
    '2013-02-30' # unfortunately our regex is not smart enough
  ], (input) ->
    it "matches the iso8601 regex #{input}", ->
      assert date_regex.test input
    it "can parse date #{input}", ->
      assert Date.parse input

  _.each [
    # valid, but we don't like
    '2009-12T12:34'
    '20090519'
    '2009123'
    '2009-123'
    '2009-222'
    '2009-001'
    '2009-W01-1'
    '2009-W51-1'
    '2009-W511'
    '2009-W33'
    '2009W511'
    '2009-W21-2'
    '2009-W21-2T01:22'
    '2009-139'
    '2009-05-19 14:39:22+0600'
    '20090621T0545Z'
    '2007-04-05T24:00'
    '2010-02-18T16:23:48.5'
    '2010-02-18T16:23:48,444'
    '2010-02-18T16:23:48,3-06:00'
    '2010-02-18T16:23.4'
    '2010-02-18T16:23,25'
    '2010-02-18T16:23.33+0600'
    '2010-02-18T16.23334444'
    '2010-02-18T16,2283'
    '2009-05-19 143922.500'
    '2009-05-19 1439,55'
    # invalid as they are not close to legit dates
    '2010-13-01'
    '2013-01-40'
    '2013-01-01 30:00'
    '2013-01-01 10:70'
    '2013-01-01 10:30:70'


    # invalid to the ISO8601 spec
    '200905'
    '2009367'
    '2009-'
    '2007-04-05T24:50'
    '2009-000'
    '2009-M511'
    '2009M511'
    '2009-05-19T14a39r'
    '2009-05-19T14:3924'
    '2009-0519'
    '2009-05-1914:39'
    '2009-05-19 14:'
    '2009-05-19r14:39'
    '2009-05-19 14a39a22'
    '200912-01'
    '2009-05-19 14:39:22+06a00'
    '2009-05-19 146922.500'
    '2010-02-18T16.5:23.35:48'
    '2010-02-18T16:23.35:48'
    '2010-02-18T16:23.35:48.45'
    '2009-05-19 14.5.44'
    '2010-02-18T16:23.33.600'
    '2010-02-18T16,25:23:48,444'
  ], (input) ->
    it "fails to match the iso8601 regex #{input}", ->
      assert not date_regex.test input

describe 'mongoose object id test', ->
  objectid_regex = new RegExp custom_types.objectid.pattern
  _.each [
    "aaaaa11111bbbbb22222cccc"
    "fffff00000eeeee99999dddd"
  ], (input) ->
    it "matches the objectId regex: #{input}", ->
      assert objectid_regex.test input

  _.each [
    5
    'foo'
    'aaaabbbb'
    'ttttt11111uuuuu22222vvvv'
    'AAAAA11111BBBBB22222CCCC'
    'ZZZZZYYYYYXXXXXUUUUUTTTT'
  ], (input) ->
    it "fails to match the objectId regex: #{input}", ->
      assert not objectid_regex.test input
