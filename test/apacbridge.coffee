apachbridge = require("../lib/util/apacbridge")
apacroot = require("apacroot")

async = require("async")

describe "version", ->
  # it "can execute nodeLookup", (done)->
  #   apachbridge.nodeLookup "JP",[apacroot.rootnode("JP","Books"),apacroot.rootnode("JP","DVD")],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,result)->
  #     console.log JSON.stringify(result,null," ")
  #     done()
  #     
  it "can execute itemLookup", (done)->
    apachbridge.nodeLookup "JP",[apacroot.rootnode("JP","Books")],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,nodeResult)->
      if(err)
        console.log JSON.stringify(err,null," ")
        return done()
      async.parallel [
        (cb) -> apachbridge.itemLookup("JP",nodeResult[0].MostGifted,cb)
        (cb) -> apachbridge.itemLookup("JP",nodeResult[0].NewReleases,cb)
        (cb) -> apachbridge.itemLookup("JP",nodeResult[0].MostWishedFor,cb)
        (cb) -> apachbridge.itemLookup("JP",nodeResult[0].TopSellers,cb)
      ],(err,results)->
        if(err)
          console.log JSON.stringify(err,null," ")
          return done()
        nodeResult[0].MostGifted = results[0]
        nodeResult[0].NewReleases = results[1]
        nodeResult[0].MostWishedFor = results[2]
        nodeResult[0].TopSellers = results[3]
        
        console.log JSON.stringify(nodeResult[0],null," ")
        done()