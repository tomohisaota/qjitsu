logger = require("log4js").getLogger("routes.index")

async = require("async")

apacroot = require("apacroot")
apachbridge = new require("../util/apacbridge")()

exports.loadRoute = (app)->
  app.get '/', (req, res) ->
    locales = []
    for locale in apacroot.locales()
      # some of the locales does not work.
      # hide from list for now
      locales.push({
        locale   : locale
        endpoint : apacroot.endpoint(locale)
        country  : apacroot.country(locale)
      })
    res.render 'localelist',{
      locales : locales
      title   : "QJITSU"
    }

  app.get '/api/:locale/:nodeid', (req, res) ->
    res.contentType('application/json; charset=utf-8')
    locale = req.params.locale
    nodeid = req.params.nodeid
    apachbridge.nodeLookup locale,[nodeid],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,nodeResults)=>
      itemIdMap = {}
      for nodeResult in nodeResults
        for ids in [nodeResult.MostGifted,nodeResult.NewReleases,nodeResult.MostWishedFor,nodeResult.TopSellers]
          continue unless(ids)
          for id in ids
            itemIdMap[id] = {}
      itemIds = Object.keys(itemIdMap)
      apachbridge.itemLookup locale,itemIds,['Small','Images'],(err,items)=>
        res.send(JSON.stringify(items,null," "))

  app.get '/:locale', (req, res) ->
    locale = req.params.locale
    for l in apacroot.locales()
      if(l == locale)
        apachbridge.nodeLookup locale,getRootNodes(locale),["BrowseNodeInfo"],(err,nodeResults)=>
          if(err)
            res.redirect "/"
            return
          rootCategories = []
          for node in nodeResults
            if(node.isRoot and node.Ancestors)
              rootCategories.push {
                Name : node.Ancestors[node.Ancestors.length - 1].Name
                NodeId : node.NodeId
                isRoot : true
              }
            else
              rootCategories.push {
                Name : node.Name
                NodeId : node.NodeId
                isRoot : false
              }
          res.render 'rootlist',{
            locale         : locale
            rootCategories : rootCategories
            title          : "QJITSU /#{locale}"
          }
          return
        return
    res.redirect "/"
    
  getRootNodes = (locale)->
    if(locale == "JP")
      return [
        465610,
        52231011,
        2250739051 ,
        562002,
        562032,
        701040,
        2129039051,
        2123630051,
        637872,
        3210991,
        2127210051,
        637630,
        86732051,
        3839151,
        2127213051,
        57240051,
        161669011,
        52391051,
        344919011,
        13299551,
        2277722051,
        361245011,
        2016927051,
        85896051,
        331952011,
        14315361,
        2016930051,
        2017305051,
        2277725051
        ]
    if(locale == "CA")
      return [
        3561347011,
        927726,
        962464,
        677211011,
        2206276011,
        952768,
        962454,
        3234171,
        2242990011,
        3006903011,
        962072,
        110218011,
        2235621011
      ]
    if(locale == "DE")
      return [
        79899031,
        357577011,
        80085031,
        78689031,
        213084031,
        541686,
        192417031,
        340844031,
        64257031,
        908824031,
        569604,
        1352367850,
        54071011,
        547664,
        541708,
        10925241,
        340853031,
        569604,
        571860,
        530485031,
        255966,
        3169011,
        340847031,
        908830031,
        180529031,
        542676,
        340850031,
        84231031,
        327473011,
        361139011,
        542064,
        12950661,
        16435121,
        193708031,
        1161660
      ]
    ids = []
    for category in apacroot.categories(locale)
      ids.push(apacroot.rootnode(locale,category))
    return ids
  
  app.get "/:locale/:nodeid", (req, res) ->  
    locale = req.params.locale
    nodeid = req.params.nodeid
    apachbridge.nodeLookup locale,[nodeid],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,result)->
      if (err)
        console.log('Error: ' + err + "\n")
        res.redirect "/#{locale}"
        return
      #logger.trace JSON.stringify(result[0],null," ")
      title = "/#{locale}"
      if(result[0].Ancestors)
        for Ancestor in result[0].Ancestors
          title = "#{title}/#{Ancestor.Name}"
      title = "#{title}/#{result[0].Name}"
      res.render 'index',{
        data:result[0]
        title          : "QJITSU #{title}"
      }
      
      # Asynchronous Prefetch
      # Prefect ancestors and children
      # it actually reduce the number of request
      prefetchIds = []
      if(result[0].Ancestors)
        for node in result[0].Ancestors
          prefetchIds.push(node.NodeId)
      if(result[0].Children)
        for node in result[0].Children
          prefetchIds.push(node.NodeId)
      if(prefetchIds.length > 10)
        prefetchIds = prefetchIds.slice(0,10)
      apachbridge.nodeLookup locale,prefetchIds,["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,result)->
        #Do nothing
      