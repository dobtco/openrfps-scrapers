# Require the necessary modules.
browser = require 'Zombie'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

module.exports = (opts, done) ->

  rfps = []

  done(rfps)
