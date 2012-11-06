logger = require("log4js").getLogger("util.apacbridge")

apacroot = require("apacroot")
async = require("async")

class ApacBridge
  newHelperForLocale : (locale)->
    OperationHelper = require('apac').OperationHelper
    return new OperationHelper {
        awsId:     process.env.APAC_ACCESS
        awsSecret: process.env.APAC_SECRET
        assocId:   process.env.APAC_ASSOCID
        endPoint:  apacroot.endpoint(locale)
    }

  nodeLookup : (locale,nodeids,responseGroup,cb)->
    logger.trace("nodeLookup")
    accessDate = new Date()
    @newHelperForLocale(locale).execute 'BrowseNodeLookup', {
        'BrowseNodeId': nodeids.join(",")
        'ResponseGroup': responseGroup.join(",")
    }, (err, rawResult)->
      #console.log JSON.stringify(rawResult,null," ")
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
        }
        if(nodeRaw.IsCategoryRoot)
          node.isRoot = nodeRaw.IsCategoryRoot[0] == "1"
        if(nodeRaw.Children)
          node.Children = []
          for child in nodeRaw.Children[0].BrowseNode
            node.Children.push {
              NodeId : child.BrowseNodeId[0]
              Name : child.Name[0]
            }
        if(nodeRaw.Ancestors)
          Ancestor = nodeRaw.Ancestors[0].BrowseNode[0]
          node.Ancestors = []
          while(true)
            node.Ancestors.unshift {
              NodeId : Ancestor.BrowseNodeId[0]
              Name : Ancestor.Name[0]
            }
            break unless(Ancestor.Ancestors)
            Ancestor = Ancestor.Ancestors[0].BrowseNode[0]
        if(nodeRaw.TopItemSet)
          for itemSetRaw in nodeRaw.TopItemSet
            if(itemSetRaw.Type[0] == "MostGifted")
              node.MostGifted = []
              for item in itemSetRaw.TopItem
                node.MostGifted.push item.ASIN[0]
            if(itemSetRaw.Type[0] == "NewReleases")
              node.NewReleases = []
              for item in itemSetRaw.TopItem
                node.NewReleases.push item.ASIN[0]
            if(itemSetRaw.Type[0] == "MostWishedFor")
              node.MostWishedFor = []
              for item in itemSetRaw.TopItem
                node.MostWishedFor.push item.ASIN[0]
            if(itemSetRaw.Type[0] == "TopSellers")
              node.TopSellers = []
              for item in itemSetRaw.TopItem
                node.TopSellers.push item.ASIN[0]
        Nodes.push(node)
      return cb(null,Nodes)

  itemLookup : (locale,itemIds,cb)->
    logger.trace("itemLookup")
    accessDate = new Date()
    @newHelperForLocale(locale).execute 'ItemLookup', {
        'ItemId': itemIds.join(",")
        'ResponseGroup': 'Medium'
    }, (err, rawResult)->
      if (err)
        return cb(err)
      #console.log JSON.stringify(rawResult,null," ")
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
        }
        if(itemRaw.ItemAttributes)
          if(itemRaw.ItemAttributes[0].Author)
            item.Author = itemRaw.ItemAttributes[0].Author[0]
          if(itemRaw.ItemAttributes[0].Manufacturer)
            item.Manufacturer = itemRaw.ItemAttributes[0].Manufacturer[0]
          if(itemRaw.ItemAttributes[0].ProductGroup)
            item.ProductGroup = itemRaw.ItemAttributes[0].ProductGroup[0]
          if(itemRaw.ItemAttributes[0].Title)
            item.Title = itemRaw.ItemAttributes[0].Title[0]
      
        if(itemRaw.MediumImage)
          item.Images = {}
          item.Images.Medium = {
            URL : itemRaw.MediumImage[0].URL[0]
            Width : parseInt(itemRaw.MediumImage[0].Width[0]["_"])
            Height : parseInt(itemRaw.MediumImage[0].Height[0]["_"])
          }
        Items.push(item)
      return cb(null,Items)
    
  nodeLookupFull : (locale,nodeids,cb)->
    logger.trace("nodeLookupFull")
    @nodeLookup locale,nodeids,["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,nodeResults)=>
      if(err)
        return cb(err)
      #console.log nodeResults
      # Create unique set of all item ids to lookup
      itemIdMap = {}
      for nodeResult in nodeResults
        for ids in [nodeResult.MostGifted,nodeResult.NewReleases,nodeResult.MostWishedFor,nodeResult.TopSellers]
          continue unless(ids)
          for id in ids
            itemIdMap[id] = {}
    
      @itemLookupByMap locale,itemIdMap,(err,itemMap)->
        if(err)
          return cb(err)
        for nodeResult in nodeResults
          nodeResult.itemMap = {}
          for ids in [nodeResult.MostGifted,nodeResult.NewReleases,nodeResult.MostWishedFor,nodeResult.TopSellers]
            continue unless(ids)
            for id in ids
              nodeResult.itemMap[id] = itemMap[id]
        cb(null,nodeResults)

  itemLookupByMap : (locale,itemIdMap,cb)=>
    logger.trace("itemLookupByMap")
    itemIds = Object.keys(itemIdMap)
    ops = []
    for ids in @sliceBySize(itemIds,10)
      ops.push(@opItemLookup(locale,ids,cb))
    console.log itemIds
    console.log @sliceBySize(itemIds,10)
    async.parallel ops,(err,results)->
      if(err)
        return cb(err)
      itemMap = {}
      for items in results
        for item in items
          itemMap[item.Itemid] = item
      return cb(null,itemMap)

  sliceBySize : (items,maxItemPerSlice)->
    result = []
    if(items.length == 0)
      return result
    for i in [0 .. (items.length-1)/maxItemPerSlice]
      result.push(items.slice(i*maxItemPerSlice,Math.min((i+1)*maxItemPerSlice,items.length)))
    return result

  opItemLookup : (locale,ids,cb)->
    return (cb) => 
      @itemLookup(locale,ids,cb)
      
module.exports = (config,cacheEngine)->
  return new ApacBridge(config,cacheEngine)