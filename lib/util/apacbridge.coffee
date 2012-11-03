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

exports.itemLookup = (locale,itemIds,cb)->
  accessDate = new Date()
  newHelperForLocale(locale).execute 'ItemLookup', {
      'ItemId': itemIds.join(",")
      'ResponseGroup': 'Medium'
  }, (err, rawResult)->
    if (err)
      return cb(err)
    unless (rawResult.ItemLookupResponse?)
      return cb(new Error("Failed to parse response"))
    itemsRaw = rawResult.ItemLookupResponse.Items[0].Item
    result = {
      Locale : locale
      Items : []
    }
    for itemRaw in itemsRaw
      item = {
        Itemid : itemRaw.ASIN[0]
        DetailPageURL : itemRaw.DetailPageURL[0]
        Timestamp : accessDate
        Author : itemRaw.ItemAttributes[0].Author[0]
        Manufacturer : itemRaw.ItemAttributes[0].Manufacturer[0]
        ProductGroup : itemRaw.ItemAttributes[0].ProductGroup[0]
        Title : itemRaw.ItemAttributes[0].Title[0]
        Images : {}
      }
      item.Images.Medium = {
        URL : itemRaw.MediumImage[0].URL[0]
        Width : parseInt(itemRaw.MediumImage[0].Width[0]["_"])
        Height : parseInt(itemRaw.MediumImage[0].Height[0]["_"])
      }
      result.Items.push(item)
    return cb(null,result)