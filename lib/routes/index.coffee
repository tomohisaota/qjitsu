async = require("async")

apacroot = require("apacroot")
apachbridge = require("../util/apacbridge")

exports.loadRoute = (app)->
  app.get '/', (req, res) ->
    apachbridge.nodeLookupFull "JP",[apacroot.rootnode("JP","Books")],(err,result)->
      if (err)
        console.log('Error: ' + err + "\n")
      res.render 'index',{data:result[0]}
  
  app.get "/:locale/:nodeid", (req, res) ->  
    locale = req.params.locale
    nodeid = req.params.nodeid
    apachbridge.nodeLookupFull locale,[nodeid],(err,result)->
      if (err)
        console.log('Error: ' + err + "\n")
      res.render 'index',{data:result[0]}