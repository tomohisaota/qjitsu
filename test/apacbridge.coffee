apachbridge = require("../lib/util/apacbridge")
apacroot = require("apacroot")

describe "version", ->
  # it "can execute nodeLookup", (done)->
  #   apachbridge.nodeLookup "JP",[apacroot.rootnode("JP","Books"),apacroot.rootnode("JP","DVD")],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,result)->
  #     console.log JSON.stringify(result,null," ")
  #     done()
  #     
  it "can execute itemLookup", (done)->
    apachbridge.nodeLookup "JP",[apacroot.rootnode("JP","Books")],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,result)->
      console.log result[0].TopSellers
      apachbridge.itemLookup "JP",result[0].TopSellers,(err,result)->
        console.log JSON.stringify(result,null," ")
        done()