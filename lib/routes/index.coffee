async = require("async")

apacroot = require("apacroot")
apachbridge = require("../util/apacbridge")

exports.index = (req, res) ->
  apachbridge.nodeLookupFull "JP",[apacroot.rootnode("JP","Books")],(err,result)->
    if (err)
      console.log('Error: ' + err + "\n")
    res.render 'index',{data:result[0]}