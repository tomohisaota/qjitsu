async = require("async")

apacroot = require("apacroot")
apachbridge = require("../util/apacbridge")

exports.index = (req, res) ->
  res.render 'index'

exports.popular = (req, res) ->
  res.contentType('application/json')
  apachbridge.nodeLookupFull "JP",[apacroot.rootnode("JP","DVD")],(err,result)->
    if (err)
      console.log('Error: ' + err + "\n")
    result = result[0]
    console.log(JSON.stringify(result,null," "))
    res.contentType('application/json; charset=utf-8')
    res.send(JSON.stringify(result,null," "))