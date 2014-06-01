fs = require 'fs'
require 'colors'

module.exports = (program, cb) ->

  fail = (msg, error) ->
    console.log "#{msg}".red
    console.log error

  if !program.args[0]
    return console.log "You must provide a <file>".red

  try
    scraper = require "../../#{program.args[0]}"
  catch error
    return fail("Couldn't find that scraper", error)

  jsonPath = program.args[0].replace(/coffee$|js$/, 'json')

  if !program.force && fs.existsSync(jsonPath)
    return cb(JSON.parse(fs.readFileSync(jsonPath)))

  try
    opts =
      limit: program.limit

    scraper opts, (parsedJson) ->
      unless program.skipsave
        writePath = program.args[0].replace(/coffee$|js$/, 'json')
        fs.writeFileSync writePath, JSON.stringify(parsedJson, null, 2)
        console.log "Cached results to #{writePath}".green

      cb(parsedJson)
  catch error
    return fail("Error during scraping", error)
