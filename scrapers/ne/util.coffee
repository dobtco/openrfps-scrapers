# http://blog.stevenlevithan.com/archives/faster-trim-javascript
trim = (str) ->
  return str.replace(/^\s\s*/, '').replace(/\s\s*$/, '')

exports.trim = trim