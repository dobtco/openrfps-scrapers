_ = require 'underscore'

_.almostEvery = (obj, predicate, context) ->
  totalSize = _.size(obj)
  filteredSize = _.size(_.filter(obj, predicate, context))
  return true if totalSize == 0
  (filteredSize / totalSize) > 0.95
