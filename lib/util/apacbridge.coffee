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
    logger.trace "nodeLookup(#{locale},[#{nodeids}],[#{responseGroup}],cb)"
    accessDate = new Date()
    @newHelperForLocale(locale).execute 'BrowseNodeLookup', {
        'BrowseNodeId': nodeids.join(",")
        'ResponseGroup': responseGroup.join(",")
    }, (err, rawResult)=>
      if (err)
        return cb(err)
      logger.trace JSON.stringify(rawResult,null," ")
      if(rawResult.BrowseNodeLookupErrorResponse?.Error)
        code = rawResult.BrowseNodeLookupErrorResponse.Error.Code
        message = rawResult.BrowseNodeLookupErrorResponse.Error.Message
        return cb(new Error(code,message))
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

  itemLookup : (locale,itemIds,responseGroup,cb)=>
    logger.trace("itemLookup(#{locale},#{itemIds},[#{responseGroup}],cb)")
    accessDate = new Date()
    @newHelperForLocale(locale).execute 'ItemLookup', {
        'ItemId': itemIds.join(",")
        'ResponseGroup': responseGroup.join(",")
    }, (err, rawResult)=>
      if (err)
        return cb(err)
      if(rawResult.ItemLookupErrorResponse?.Error)
        code = rawResult.ItemLookupErrorResponse.Error.Code
        message = rawResult.ItemLookupErrorResponse.Error.Message
        return cb(new Error(code,message))
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
    logger.trace("nodeLookupFull(#{locale},[#{nodeids}],cb)")
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
      @itemLookup locale,itemIds,['Small','Images'],(err,items)=>
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
# This class slices id list, and run query in series
class ApacBridgeWithSlicing extends ApacBridge
  MAX_NODE_LOOKUP : 10
  MAX_ITEM_LOOKUP : 10
  
  nodeLookup : (locale,nodeids,responseGroup,cb)=>
    if(nodeids.length <= @MAX_NODE_LOOKUP)
      # Do nothing if ids can processed in single query
      return super(locale,nodeids,responseGroup,cb)
    ops = []
    for ids in @sliceBySize(nodeids,@MAX_NODE_LOOKUP)
      ops.push(@opNodeLookupWithoutCache(locale,ids,responseGroup,cb))
    async.series ops,(err,results)=>
      if(err)
        return cb(err)
      resultAll = []
      for result in results
        for node in result
          resultAll.push(node)
      return cb(null,resultAll)

  itemLookup : (locale,itemIds,responseGroup,cb)=>
    if(itemIds.length <= @MAX_ITEM_LOOKUP)
      # Do nothing if ids can processed in single query
      return super(locale,itemIds,responseGroup,cb)
    logger.trace("Slicing itemLookup(#{locale},#{itemIds},[#{responseGroup}],cb)")
    ops = []
    for ids in @sliceBySize(itemIds,@MAX_ITEM_LOOKUP)
      ops.push(@opItemLookupWithoutCache(locale,ids,responseGroup,cb))
    async.series ops,(err,results)=>
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

  opItemLookupWithoutCache : (locale,ids,responseGroup,cb)=>
    return (cb) => 
      @itemLookup(locale,ids,responseGroup,cb,true)

class CachedApacBridge extends ApacBridgeWithSlicing
  cacher : null
  NODE_TTL : 1000 * 60 * 60 * 3
  ITEM_TTL : 1000 * 60 * 60
  
  constructor: (config,cacher)->
    super(config)
    @superRef = CachedApacBridge.__super__
    @cacher = cacher
    
  nodeLookup : (locale,nodeids,responseGroup,cb,noCache)=>
    if(noCache)
      return super(locale,nodeids,responseGroup,cb)
    logger.trace "Cached nodeLookup(#{locale},[#{nodeids}],[#{responseGroup}],cb)"
    nodeIdsToFetch = []
    resultAll = []
    cacheKeyList = []
    for nodeId in nodeids
      cacheKeyList.push(@nodeCacheKey(locale,nodeId,responseGroup))
    @cacher.mget cacheKeyList,(err,cachedValueMap)=>
      for nodeId in nodeids
        cacheKey = @nodeCacheKey(locale,nodeId,responseGroup)
        cache = cachedValueMap[cacheKey]
        if(cache)
          resultAll.push(cache)
          continue
        nodeIdsToFetch.push(nodeId)
      if(nodeIdsToFetch.length == 0)
        return cb(null,resultAll)
      @superRef.nodeLookup.apply this,[locale,nodeIdsToFetch,responseGroup,(err,nodes)=>
        if(err)
          return cb(err)
        valueToBeCached = {}
        for node in nodes
          cacheKey = @nodeCacheKey(locale,node.NodeId,responseGroup)
          valueToBeCached[cacheKey] = node
          resultAll.push(node)
        @cacher.mset valueToBeCached,@NODE_TTL,(err)=>
          return cb(null,resultAll)
      ]
  
  nodeCacheKey : (locale,nodeid,responseGroup)=>
    return "node-#{locale}-#{nodeid}-[#{responseGroup}]"
      
  itemLookup : (locale,itemIds,responseGroup,cb,noCache)=>
    if(noCache)
      return super(locale,itemIds,responseGroup,cb)
    logger.trace("Cached itemLookup(#{locale},#{itemIds},[#{responseGroup}],cb)")
    itemIdsToFetch = []
    resultAll = []
    cacheKeyList = []
    for itemId in itemIds
      cacheKeyList.push(@itemCacheKey(locale,itemId,responseGroup))
    @cacher.mget cacheKeyList,(err,cachedValueMap)=>
      if(err)
        return cb(err)
      for itemId in itemIds
        cacheKey = @itemCacheKey(locale,itemId,responseGroup)
        cache = cachedValueMap[cacheKey]
        if(cache)
          resultAll.push(cache)
          continue
        itemIdsToFetch.push(itemId)
      if(itemIdsToFetch.length == 0)
        return cb(null,resultAll)
      @superRef.itemLookup.apply this,[locale,itemIdsToFetch,responseGroup,(err,items)=>
        if(err)
          return cb(err)
        valueToBeCached = {}
        for item in items
          cacheKey = @itemCacheKey(locale,item.ItemId,responseGroup)
          valueToBeCached[cacheKey] = item
          resultAll.push(item)
        @cacher.mset valueToBeCached,@ITEM_TTL,(err)=>
          return cb(null,resultAll)
      ]
      
  itemCacheKey : (locale,itemId,responseGroup)=>
    return "item-#{locale}-#{itemId}-[#{responseGroup}]"

    
module.exports = (config)->
  return new CachedApacBridge(config,require("./cacher"))