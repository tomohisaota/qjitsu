async = require("async")

apacroot = require("apacroot")
apachbridge = require("../util/apacbridge")

exports.index = (req, res) ->
  res.render 'index'

exports.popular = (req, res) ->
  res.contentType('application/json')
  nodeLookup "JP",apacroot.rootnode("JP","Books"),(err,result)->
    if (err)
      console.log('Error: ' + err + "\n")
    console.log(JSON.stringify(result,null," "))
    res.contentType('application/json; charset=utf-8')
    res.send(JSON.stringify(result,null," "))

nodeLookup = (locale,nodeid,cb)->
  apachbridge.nodeLookup locale,[nodeid],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,nodeResult)->
    if(err)
      return cb(err)
    async.parallel [
      (cb) -> apachbridge.itemLookup("JP",nodeResult[0].MostGifted,cb)
      (cb) -> apachbridge.itemLookup("JP",nodeResult[0].NewReleases,cb)
      (cb) -> apachbridge.itemLookup("JP",nodeResult[0].MostWishedFor,cb)
      (cb) -> apachbridge.itemLookup("JP",nodeResult[0].TopSellers,cb)
    ],(err,results)->
      if(err)
        return cb(err)
      nodeResult[0].MostGifted = results[0]
      nodeResult[0].NewReleases = results[1]
      nodeResult[0].MostWishedFor = results[2]
      nodeResult[0].TopSellers = results[3]
      return cb(null,nodeResult[0])