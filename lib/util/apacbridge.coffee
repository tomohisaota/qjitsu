apacroot = require("apacroot")

newHelperForLocale = (locale)->
  OperationHelper = require('apac').OperationHelper
  return new OperationHelper {
      awsId:     process.env.APAC_ACCESS
      awsSecret: process.env.APAC_SECRET
      assocId:   process.env.APAC_ASSOCID
      endPoint:  apacroot.endpoint(locale)
  }

exports.nodeLookup = (locale,nodeid,cb)->
  accessDate = new Date()
  newHelperForLocale(locale).execute 'BrowseNodeLookup', {
      'BrowseNodeId': nodeid
  }, (err, rawResult)->
    if (err)
      return cb(err)
    unless (rawResult.BrowseNodeLookupResponse?)
      return cb(new Error("Failed to parse response"))
    #console.log JSON.stringify(rawResult,null," ")
    rawResult = rawResult.BrowseNodeLookupResponse.BrowseNodes[0].BrowseNode[0]
    result = {
      locale : locale
      id : rawResult.BrowseNodeId[0]
      name : rawResult.Name[0]
      timestamp : accessDate
      children : []
      ancestors : []
    }
    if(rawResult.IsCategoryRoot)
      result.isRoot = rawResult.IsCategoryRoot[0] == "1"
    if(rawResult.Children)
      for child in rawResult.Children[0].BrowseNode
        result.children.push {
          id : child.BrowseNodeId[0]
          name : child.Name[0]
        }
    if(rawResult.Ancestors)
      for ancestor in rawResult.Ancestors[0].BrowseNode
        result.ancestors.push {
          id : ancestor.BrowseNodeId[0]
          name : ancestor.Name[0]
        }
    return cb(null,result)
    
exports.topSellers = (locale,nodeid,cb)->
  accessDate = new Date()
  newHelperForLocale(locale).execute 'BrowseNodeLookup', {
      'BrowseNodeId': nodeid
      'ResponseGroup': 'TopSellers'
  }, (err, rawResult)->
    if (err)
      return cb(err)
    unless (rawResult.BrowseNodeLookupResponse?)
      return cb(new Error("Failed to parse response"))
    rawResult = rawResult.BrowseNodeLookupResponse.BrowseNodes[0].BrowseNode[0]
    result = {
      locale : locale
      id : rawResult.BrowseNodeId[0]
      name : rawResult.Name[0]
      timestamp : accessDate
      topsellers:[]
    }
    for item in rawResult.TopSellers[0].TopSeller
      result.topsellers.push item.ASIN[0]
    return cb(null,result)
