apacroot = require("apacroot")

newHelperForLocale = (locale)->
  OperationHelper = require('apac').OperationHelper
  return new OperationHelper {
      awsId:     process.env.APAC_ACCESS
      awsSecret: process.env.APAC_SECRET
      assocId:   process.env.APAC_ASSOCID
      endPoint:  apacroot.endpoint(locale)
  }

exports.nodeLookup = (locale,nodeids,cb)->
  accessDate = new Date()
  newHelperForLocale(locale).execute 'BrowseNodeLookup', {
      'BrowseNodeId': nodeids.join(",")
  }, (err, rawResult)->
    if (err)
      return cb(err)
    unless (rawResult.BrowseNodeLookupResponse?)
      return cb(new Error("Failed to parse response"))
    #console.log JSON.stringify(rawResult,null," ")
    rawResult = rawResult.BrowseNodeLookupResponse.BrowseNodes[0].BrowseNode
    Nodes = []
    for nodeRaw in rawResult
      node = {
        Locale : locale
        NodeId : nodeRaw.BrowseNodeId[0]
        Name : nodeRaw.Name[0]
        Timestamp : accessDate
        Children : []
        Ancestors : []
      }
      if(nodeRaw.IsCategoryRoot)
        node.isRoot = nodeRaw.IsCategoryRoot[0] == "1"
      if(nodeRaw.Children)
        for child in nodeRaw.Children[0].BrowseNode
          node.Children.push {
            NodeId : child.BrowseNodeId[0]
            Name : child.Name[0]
          }
      if(nodeRaw.Ancestors)
        for ancestor in nodeRaw.Ancestors[0].BrowseNode
          node.Ancestors.push {
            NodeId : ancestor.BrowseNodeId[0]
            Name : ancestor.Name[0]
          }
      Nodes.push(node)
    return cb(null,Nodes)
    
exports.topSellers = (locale,nodeids,cb)->
  accessDate = new Date()
  newHelperForLocale(locale).execute 'BrowseNodeLookup', {
      'BrowseNodeId': nodeids.join(",")
      'ResponseGroup': 'TopSellers'
  }, (err, rawResult)->
    if (err)
      return cb(err)
    unless (rawResult.BrowseNodeLookupResponse?)
      return cb(new Error("Failed to parse response"))
    rawResult = rawResult.BrowseNodeLookupResponse.BrowseNodes[0].BrowseNode
    Nodes = []
    for nodeRaw in rawResult
      node = {
        Locale : locale
        NodeId : nodeRaw.BrowseNodeId[0]
        Name : nodeRaw.Name[0]
        Timestamp : accessDate
        Topsellers:[]
      }
      for item in nodeRaw.TopSellers[0].TopSeller
        node.Topsellers.push item.ASIN[0]
      Nodes.push(node)
    return cb(null,Nodes)

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
    Items = []
    for itemRaw in itemsRaw
      item = {
        Locale : locale
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
      Items.push(item)
    return cb(null,Items)