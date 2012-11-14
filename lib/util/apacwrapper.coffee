class Node
  raw : null
  
  constructor: (raw)->
    @raw = raw
  
  @::__defineGetter__ "Name", ->
    return null unless(@raw.Name)
    return @raw.Name[0]

  @::__defineGetter__ "SmartName", ->
    return @Ancestors[0].Name if(@IsCategoryRoot)
    return @Name
  
  @::__defineGetter__ "BrowseNodeId", ->
    return null unless(@raw.BrowseNodeId)
    return parseInt(@raw.BrowseNodeId[0])
    
  @::__defineGetter__ "IsCategoryRoot", ->
    return false unless(@raw.IsCategoryRoot)
    return @raw.IsCategoryRoot[0] == "1"
    
  @::__defineGetter__ "Children", ->
    return null unless(@raw.Children)
    result = []
    for child in @raw.Children[0].BrowseNode
      result.push(new Node(child))
    return result
    
  @::__defineGetter__ "Ancestors", ->
    return null unless(@raw.Ancestors)
    result = []
    for ancestor in @raw.Ancestors[0].BrowseNode
      result.push(new Node(ancestor))
    return result

  @::__defineGetter__ "AncestorsFromTop", ->
    unless(@Ancestors and @Ancestors.length != 0)
      return [[this]]
    result = []
    for Ancestor in @Ancestors
      for temp in Ancestor.AncestorsFromTop
        temp.push(this)
        result.push(temp)
    return result
    
  @::__defineGetter__ "MostGifted", ->
    return null unless(@raw.TopItemSet)
    for itemSetRaw in @raw.TopItemSet
      if(itemSetRaw.Type[0] == "MostGifted")
        items = []
        for item in itemSetRaw.TopItem
          items.push(new Item(item))
        return items
    return null

  @::__defineGetter__ "NewReleases", ->
    return null unless(@raw.TopItemSet)
    for itemSetRaw in @raw.TopItemSet
      if(itemSetRaw.Type[0] == "NewReleases")
        items = []
        for item in itemSetRaw.TopItem
          items.push(new Item(item))
        return items
    return null

  @::__defineGetter__ "MostWishedFor", ->
    return null unless(@raw.TopItemSet)
    for itemSetRaw in @raw.TopItemSet
      if(itemSetRaw.Type[0] == "MostWishedFor")
        items = []
        for item in itemSetRaw.TopItem
          items.push(new Item(item))
        return items
    return null

  @::__defineGetter__ "TopSellers", ->
    return null unless(@raw.TopItemSet)
    for itemSetRaw in @raw.TopItemSet
      if(itemSetRaw.Type[0] == "TopSellers")
        items = []
        for item in itemSetRaw.TopItem
          items.push(new Item(item))
        return items
    return null
    
  @::__defineGetter__ "isError", ->
    return @raw.Error?

  @::__defineGetter__ "Error", ->
    return null unless(@raw.Error)
    for error in @raw.Error
      if(error.Message[0].indexOf(@BrowseNodeId) != -1)
        return error
    return @raw.Error[0]
  

class Item
  raw : null
  
  constructor: (raw)->
    @raw = raw
  
  @::__defineGetter__ "Title", ->
    return null unless(@raw.ItemAttributes and @raw.ItemAttributes[0].Title)
    return @raw.ItemAttributes[0].Title[0]

  @::__defineGetter__ "ASIN", ->
    return null unless(@raw.ASIN)
    return @raw.ASIN[0]

  @::__defineGetter__ "DetailPageURL", ->
    return null unless(@raw.DetailPageURL)
    return @raw.DetailPageURL[0]

  @::__defineGetter__ "MediumImage", ->
    return null unless(@raw.MediumImage)
    return {
      URL    : @raw.MediumImage[0].URL[0]
      Width  : parseInt(@raw.MediumImage[0].Width[0]["_"])
      Height : parseInt(@raw.MediumImage[0].Height[0]["_"])
    }
    
  @::__defineGetter__ "isError", ->
    return @raw.Error?

  @::__defineGetter__ "Error", ->
    return null unless(@raw.Error)
    for error in @raw.Error
      if(error.Message[0].indexOf(@ASIN) != -1)
        return error
    return @raw.Error[0]
  
module.exports.Node = Node
module.exports.Item = Item

module.exports.wrapNode = (nodeRawArray)->
  nodeArray = []
  for nodeRaw in nodeRawArray
    nodeArray.push(new Node(nodeRaw))
  return nodeArray
  
module.exports.wrapItem = (itemRawArray)->
  itemArray = []
  for itemRaw in itemRawArray
    itemArray.push(new Item(itemRaw))
  return itemArray