chai = require('chai')
expect = chai.expect  

apacbridge = new require("../lib/util/apacbridge")()
apacroot = require("apacroot")

async = require("async")

wrapper = require("../lib/util/apacwrapper")

TEST_LOCALE = "JP"
TEST_BROWSEID = [465610]
TEST_ITEMID = ["B009SIJ7G8"]#,"B0081N1ZFM"]

describe "BrowseNode Test", ->
  it "can fetch BrowseNodeInfo", (done)->
    apacbridge.nodeLookup TEST_LOCALE,TEST_BROWSEID,["BrowseNodeInfo"],(err,nodeRawArray)->
      expect(err,"Response Error").to.be.null
      expect(nodeRawArray.length).equal(1)
      node = new wrapper.Node(nodeRawArray[0])
      expect(node.Children).to.be.not.null
      expect(node.Ancestors).to.be.not.null
      done()
  
  it "can fetch MostGifted", (done)->
    apacbridge.nodeLookup TEST_LOCALE,TEST_BROWSEID,["MostGifted"],(err,nodeRawArray)->
      expect(err,"Response Error").to.be.null
      expect(nodeRawArray.length).equal(1)
      node = new wrapper.Node(nodeRawArray[0])
      expect(node.MostGifted).to.be.not.null
      expect(node.MostGifted.length).equal(10)
      done()

  it "can fetch NewReleases", (done)->
    apacbridge.nodeLookup TEST_LOCALE,TEST_BROWSEID,["NewReleases"],(err,nodeRawArray)->
      expect(err,"Response Error").to.be.null
      expect(nodeRawArray.length).equal(1)
      node = new wrapper.Node(nodeRawArray[0])
      expect(node.NewReleases).to.be.not.null
      expect(node.NewReleases.length).equal(10)
      done()

  it "can fetch MostWishedFor", (done)->
    apacbridge.nodeLookup TEST_LOCALE,TEST_BROWSEID,["MostWishedFor"],(err,nodeRawArray)->
      expect(err,"Response Error").to.be.null
      expect(nodeRawArray.length).equal(1)
      node = new wrapper.Node(nodeRawArray[0])
      expect(node.MostWishedFor).to.be.not.null
      expect(node.MostWishedFor.length).equal(10)
      done()

  it "can fetch TopSellers", (done)->
    apacbridge.nodeLookup TEST_LOCALE,TEST_BROWSEID,["TopSellers"],(err,nodeRawArray)->
      expect(err,"Response Error").to.be.null
      expect(nodeRawArray.length).equal(1)
      node = new wrapper.Node(nodeRawArray[0])
      expect(node.TopSellers).to.be.not.null
      expect(node.TopSellers.length).equal(10)
      done()
      
describe "ItemLookup Test", ->
  it "can fetch ItemLookup", (done)->
    apacbridge.itemLookup TEST_LOCALE,TEST_ITEMID,['Small','Images'],(err,itemsRaw)=>
      expect(err,"Response Error").to.be.null
      expect(itemsRaw.length).equal(1)
      item = new wrapper.Item(itemsRaw[0])
      console.log JSON.stringify(item.Error,null," ")
      done()