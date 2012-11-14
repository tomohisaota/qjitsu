logger = require("log4js").getLogger("util.apacbridge")

apac = require('apac')
apacroot = require("apacroot")
async = require("async")
wrapper = require("./apacwrapper")

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
    if(nodeids.length == 0)
      return cb(null,[])
    @newHelperForLocale(locale).execute 'BrowseNodeLookup', {
        'BrowseNodeId': nodeids.join(",")
        'ResponseGroup': responseGroup.join(",")
    }, (err, rawResult)=>
      if (err)
        return cb(err)
      nodeRawMap = {}
      if(rawResult.BrowseNodeLookupResponse.BrowseNodes[0].BrowseNode)
        for nodeRaw in rawResult.BrowseNodeLookupResponse.BrowseNodes[0].BrowseNode
          nodeId = parseInt(nodeRaw.BrowseNodeId[0])
          nodeRawMap[nodeId] = nodeRaw
      if(rawResult.BrowseNodeLookupResponse.BrowseNodes[0].Request[0].Errors)
        for nodeId in nodeids
          continue if(nodeRawMap[nodeId])
          nodeRawMap[nodeId] = rawResult.BrowseNodeLookupResponse.BrowseNodes[0].Request[0].Errors[0]
          #Save BrowseNodeId for convinience
          nodeRawMap[nodeId].BrowseNodeId = [nodeId]
      nodeRawArray = []
      for nodeId in nodeids
        nodeRawArray.push(nodeRawMap[nodeId])
      return cb(null,nodeRawArray)

  itemLookup : (locale,itemIds,responseGroup,cb)=>
    logger.trace("itemLookup(#{locale},#{itemIds},[#{responseGroup}],cb)")
    if(itemIds.length == 0)
      return cb(null,[])
    @newHelperForLocale(locale).execute 'ItemLookup', {
        'ItemId': itemIds.join(",")
        'ResponseGroup': responseGroup.join(",")
    }, (err, rawResult)=>
      if (err)
        return cb(err)
      itemRawMap = {}
      if(rawResult.ItemLookupResponse.Items[0].Item)
        for itemRaw in rawResult.ItemLookupResponse.Items[0].Item
          itemId = itemRaw.ASIN[0]
          itemRawMap[itemId] = itemRaw
      if(rawResult.ItemLookupResponse.Items[0].Request[0].Errors)
        for itemId in itemIds
          continue if(itemRawMap[itemId])
          itemRawMap[itemId] = rawResult.ItemLookupResponse.Items[0].Request[0].Errors[0]
          #Save ItemId for convinience
          itemRawMap[itemId].ASIN = [itemId]
      itemRawArray = []
      for itemId in itemIds
        itemRawArray.push(itemRawMap[itemId])
      return cb(null,itemRawArray)
          
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
      nodeRawArray = []
      for nodeRawArrayPartial in results
        for node in nodeRawArrayPartial
          nodeRawArray.push(node)
      return cb(null,nodeRawArray)

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
      itemArrayRaw = []
      for itemArrayRawPartial in results
        for itemRaw in itemArrayRawPartial
          itemArrayRaw.push(itemRaw)
      return cb(null,itemArrayRaw)

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
    cachedRawNodeMap = {}
    cacheKeyList = []
    for nodeId in nodeids
      cacheKeyList.push(@nodeCacheKey(locale,nodeId,responseGroup))
    @cacher.mget cacheKeyList,(err,cachedValueMap)=>
      if(err)
        return cb(err)
      for nodeId in nodeids
        cacheKey = @nodeCacheKey(locale,nodeId,responseGroup)
        cache = cachedValueMap[cacheKey]
        if(cache)
          cachedRawNodeMap[nodeId] = cache
          continue
        nodeIdsToFetch.push(nodeId)
      @superRef.nodeLookup.apply this,[locale,nodeIdsToFetch,responseGroup,(err,nodes)=>
        if(err)
          return cb(err)
        fetchedRawNodeMap = {}
        valueToBeCached = {}
        if(nodeIdsToFetch.length != 0)
          for i in [0 .. nodeIdsToFetch.length-1]
            cacheKey = @nodeCacheKey(locale,nodeIdsToFetch[i],responseGroup)
            fetchedRawNodeMap[nodeIdsToFetch[i]] = nodes[i]
            valueToBeCached[cacheKey] = nodes[i]
        @cacher.mset valueToBeCached,@NODE_TTL,(err)=>
          nodeRawArray = []
          for nodeId in nodeids
            if(cachedRawNodeMap[nodeId])
              nodeRawArray.push(cachedRawNodeMap[nodeId])
            else
              nodeRawArray.push(fetchedRawNodeMap[nodeId])
          return cb(null,nodeRawArray)
      ]
  
  nodeCacheKey : (locale,nodeid,responseGroup)=>
    return "node-#{locale}-#{nodeid}-[#{responseGroup}]"
      
  itemLookup : (locale,itemIds,responseGroup,cb,noCache)=>
    if(noCache)
      return super(locale,itemIds,responseGroup,cb)
    logger.trace("Cached itemLookup(#{locale},#{itemIds},[#{responseGroup}],cb)")
    itemIdsToFetch = []
    cachedRawItemMap = {}
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
          cachedRawItemMap[itemId] = cache
          continue
        itemIdsToFetch.push(itemId)
      @superRef.itemLookup.apply this,[locale,itemIdsToFetch,responseGroup,(err,items)=>
        if(err)
          return cb(err)
        fetchedRawItemMap = {}
        valueToBeCached = {}
        if(itemIdsToFetch.length != 0)
          for i in [0 .. itemIdsToFetch.length-1]
            cacheKey = @itemCacheKey(locale,itemIdsToFetch[i],responseGroup)
            fetchedRawItemMap[itemIdsToFetch[i]] = items[i]
            valueToBeCached[cacheKey] = items[i]
        @cacher.mset valueToBeCached,@ITEM_TTL,(err)=>
          itemRawArray = []
          for itemId in itemIds
            if(cachedRawItemMap[itemId])
              itemRawArray.push(cachedRawItemMap[itemId])
            else
              itemRawArray.push(fetchedRawItemMap[itemId])
          return cb(null,itemRawArray)
      ]
      
  itemCacheKey : (locale,itemId,responseGroup)=>
    return "item-#{locale}-#{itemId}-[#{responseGroup}]"

module.exports = (config)->
  return new CachedApacBridge(config,require("./cacher"))