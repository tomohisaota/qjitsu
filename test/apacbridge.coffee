apachbridge = require("../lib/util/apacbridge")
apacroot = require("apacroot")

describe "version", ->
  it "can execute nodeLookup", (done)->
    apachbridge.nodeLookup "JP",[apacroot.rootnode("JP","Books"),apacroot.rootnode("JP","DVD")],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,result)->
      console.log JSON.stringify(result,null," ")
      done()
      
  # it "can execute itemLookup", (done)->
  #   apachbridge.itemLookup "JP",["4041203554","4088705319"],(err,result)->
  #     console.log JSON.stringify(result,null," ")
  #     done()