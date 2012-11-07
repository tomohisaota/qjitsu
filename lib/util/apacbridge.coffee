logger = require("log4js").getLogger("util.apacbridge")

apac = require('apac')
apacroot = require("apacroot")
async = require("async")

class ApacBridge
  config : null
  
  constructor: (config)->
    unless(config)
      config = {
        APAC_ACCESS:  process.env.APAC_ACCESS
        APAC_SECRET:  process.env.APAC_SECRET
        APAC_ASSOCID: process.env.APAC_ASSOCID
      }
    @config = config
  
  newHelperForLocale : (locale)=>
    #logger.trace "newHelperForLocale(#{locale})"
    return new apac.OperationHelper {
        awsId:     @config.APAC_ACCESS
        awsSecret: @config.APAC_SECRET
        assocId:   @config.APAC_ASSOCID
        endPoint:  apacroot.endpoint(locale)
    }

  nodeLookup : (locale,nodeids,responseGroup,cb)=>
    logger.trace "nodeLookup(#{locale},#{nodeids},#{responseGroup},cb)"
    accessDate = new Date()
    @newHelperForLocale(locale).execute 'BrowseNodeLookup', {
        'BrowseNodeId': nodeids.join(",")
        'ResponseGroup': responseGroup.join(",")
    }, (err, rawResult)=>
      if (err)
        return cb(err)
      unless (rawResult.BrowseNodeLookupResponse?)
        return cb(new Error("Failed to parse response"))
      #logger.trace JSON.stringify(rawResult,null," ")
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
            temp = {}
            temp.NodeId = Ancestor.BrowseNodeId[0]
            if(Ancestor.Name)
              temp.Name =Ancestor.Name[0]
            else
              temp.Name =Ancestor.BrowseNodeId[0]
            node.Ancestors.unshift temp
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

  itemLookup : (locale,itemIds,cb)=>
    logger.trace("itemLookup(#{locale},#{itemIds},cb)")
    accessDate = new Date()
    @newHelperForLocale(locale).execute 'ItemLookup', {
        'ItemId': itemIds.join(",")
        'ResponseGroup': 'Medium'
    }, (err, rawResult)=>
      if (err)
        return cb(err)
      unless (rawResult.ItemLookupResponse?)
        return cb(new Error("Failed to parse response"))
      Items = []
      #logger.trace JSON.stringify(rawResult,null," ")
      unless(rawResult.ItemLookupResponse.Items[0].Item)
        return cb(null,Items)
      itemsRaw = rawResult.ItemLookupResponse.Items[0].Item
      for itemRaw in itemsRaw
        item = {
          Locale : locale
          ItemId : itemRaw.ASIN[0]
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
      
  nodeLookupFull : (locale,nodeids,cb)=>
    logger.trace("nodeLookupFull(#{locale},#{nodeids},cb)")
    @nodeLookup locale,nodeids,["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,nodeResults)=>
      if(err)
        return cb(err)
      # Create unique set of all item ids to lookup
      itemIdMap = {}
      for nodeResult in nodeResults
        for ids in [nodeResult.MostGifted,nodeResult.NewReleases,nodeResult.MostWishedFor,nodeResult.TopSellers]
          continue unless(ids)
          for id in ids
            itemIdMap[id] = {}
      itemIds = Object.keys(itemIdMap)

      @itemLookup locale,itemIds,(err,items)=>
        if(err)
          return cb(err)
        itemMap = {}
        for item in items
          itemMap[item.ItemId] = item
        for nodeResult in nodeResults
          nodeResult.itemMap = {}
          for ids in [nodeResult.MostGifted,nodeResult.NewReleases,nodeResult.MostWishedFor,nodeResult.TopSellers]
            continue unless(ids)
            for id in ids
              nodeResult.itemMap[id] = itemMap[id]
        cb(null,nodeResults)
          
# Amazon Product Advertising API has limit for number of items in 1 query
# This class slices id list, and run query in paralle
class ApacBridgeWithSlicing extends ApacBridge
  MAX_NODE_LOOKUP : 10
  MAX_ITEM_LOOKUP : 10
  
  nodeLookup : (locale,nodeids,responseGroup,cb)=>
    if(nodeids.length <= @MAX_NODE_LOOKUP)
      # Do nothing if ids can processed in single query
      return super(locale,nodeids,responseGroup,cb)
    logger.trace "Slicing nodeLookup(#{locale},#{nodeids},#{responseGroup},cb)"
    ops = []
    for ids in @sliceBySize(nodeids,@MAX_NODE_LOOKUP)
      ops.push(@opNodeLookupWithoutCache(locale,ids,responseGroup,cb))
    async.parallel ops,(err,results)=>
      if(err)
        return cb(err)
      resultAll = []
      for result in results
        for node in result
          resultAll.push(node)
      return cb(null,resultAll)

  itemLookup : (locale,itemIds,cb)=>
    if(itemIds.length <= @MAX_ITEM_LOOKUP)
      # Do nothing if ids can processed in single query
      return super(locale,itemIds,cb)
    logger.trace("Slicing itemLookup(#{locale},#{itemIds},cb)")
    ops = []
    for ids in @sliceBySize(itemIds,@MAX_ITEM_LOOKUP)
      ops.push(@opItemLookupWithoutCache(locale,ids,cb))
    async.parallel ops,(err,results)=>
      if(err)
        return cb(err)
      resultAll = []
      for result in results
        for item in result
          resultAll.push(item)
      return cb(null,resultAll)

  sliceBySize : (items,maxItemPerSlice)=>
    result = []
    if(items.length == 0)
      return result
    for i in [0 .. (items.length-1)/maxItemPerSlice]
      result.push(items.slice(i*maxItemPerSlice,Math.min((i+1)*maxItemPerSlice,items.length)))
    return result

  opNodeLookupWithoutCache : (locale,nodeids,responseGroup,cb)=>
    return (cb) => 
      @nodeLookup(locale,nodeids,responseGroup,cb,true)

  opItemLookupWithoutCache : (locale,ids,cb)=>
    return (cb) => 
      @itemLookup(locale,ids,cb,true)

class CachedApacBridge extends ApacBridgeWithSlicing
  nodeCache : null
  itemCache : null
  
  constructor: (config)->
    super(config)
    @nodeCache = {}
    @itemCache = {}
    
  nodeLookup : (locale,nodeids,responseGroup,cb,noCache)=>
    if(noCache)
      return super(locale,nodeids,responseGroup,cb)
    logger.trace "Cached nodeLookup(#{locale},#{nodeids},#{responseGroup},cb)"
    nodeIdsToFetch = []
    resultAll = []
    for nodeId in nodeids
      if(@nodeCache[nodeId])
        if(new Date().getTime() - @nodeCache[nodeId].Timestamp.getTime() < 1000 * 60 * 10) # 10 min
          logger.trace "node cache hit #{nodeId}"
          resultAll.push(@nodeCache[nodeId])
          continue
      nodeIdsToFetch.push(nodeId)
    if(nodeIdsToFetch.length == 0)
      return cb(null,resultAll)
    super locale,nodeIdsToFetch,responseGroup,(err,nodes)=>
      if(err)
        return cb(err)
      for node in nodes
        logger.trace "node cache save #{node.NodeId}"
        @nodeCache[node.NodeId] = node
        resultAll.push(node)
      return cb(null,resultAll)
      
  itemLookup : (locale,itemIds,cb,noCache)=>
    if(noCache)
      return super(locale,itemIds,cb)
    logger.trace("Cached itemLookup(#{locale},#{itemIds},cb)")
    itemIdsToFetch = []
    resultAll = []
    for itemId in itemIds
      if(@itemCache[itemId])
        if(new Date().getTime() - @itemCache[itemId].Timestamp.getTime() < 1000 * 60 * 10) # 10 min
          logger.trace "item cache hit #{itemId}"
          resultAll.push(@itemCache[itemId])
          continue
      itemIdsToFetch.push(itemId)
    if(itemIdsToFetch.length == 0)
      return cb(null,resultAll)
    super locale,itemIdsToFetch,(err,items)=>
      if(err)
        return cb(err)
      for item in items
        logger.trace "item cache save #{item.ItemId}"
        @itemCache[item.ItemId] = item
        resultAll.push(item)
      return cb(null,resultAll)
    
module.exports = (config)->
  return new CachedApacBridge(config)