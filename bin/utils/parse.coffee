require 'colors'

module.exports = (program) ->

  fail = (msg, error) ->
    console.log "#{msg}".red
    console.log error

  try
    scraper = require('../../' + program.args[0])
  catch error
    return fail("Couldn't find that scraper", error)

  try
    parsedJson = scraper()
  catch error
    return fail("Error during scraping", error)

  parsedJson
