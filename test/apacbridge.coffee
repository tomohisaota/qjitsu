apacbridge = new require("../lib/util/apacbridge")()
apacroot = require("apacroot")

async = require("async")

describe "version", ->
  # it "can execute nodeLookup", (done)->
  #   apacbridge.nodeLookup "JP",[apacroot.rootnode("JP","Books"),apacroot.rootnode("JP","DVD")],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,result)->
  #     console.log JSON.stringify(result,null," ")
  #     done()
  #     
  it "can execute itemLookup", (done)->
    apacbridge.nodeLookup "JP",[apacroot.rootnode("JP","Books")],["BrowseNodeInfo"],(err,nodeResult)->
      if(err)
        console.log JSON.stringify(err,null," ")
        return done()
      console.log JSON.stringify(nodeResult[0],null," ")
      done()