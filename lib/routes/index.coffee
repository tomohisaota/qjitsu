logger = require("log4js").getLogger("routes.index")

async = require("async")

apacroot = require("apacroot")
apachbridge = new require("../util/apacbridge")()
wrapper = require("../util/apacwrapper")

exports.loadRoute = (app)->
  app.get '/', (req, res) ->
    locales = []
    for locale in apacroot.locales()
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
    apachbridge.nodeLookup locale,[nodeid],["BrowseNodeInfo","MostGifted","NewReleases","MostWishedFor","TopSellers"],(err,nodeRawArray)=>
      if(err)
        res.redirect "/"
        return
      nodes = wrapper.wrapNode(nodeRawArray)
      itemIdMap = {}
      for node in nodes
        for items in [node.MostGifted,node.NewReleases,node.MostWishedFor,node.TopSellers]
          continue unless(items)
          for item in items
            itemIdMap[item.ASIN] = {}
      itemIds = Object.keys(itemIdMap)
      apachbridge.itemLookup locale,itemIds,['Small','Images'],(err,itemRawArray)=>
        if(err)
          res.redirect "/"
          return
        itemsResponse = []
        for item in wrapper.wrapItem(itemRawArray)
          itemsResponse.push({
            ASIN : item.ASIN
            Title : item.Title
            DetailPageURL : item.DetailPageURL
            MediumImage : item.MediumImage
          })
        res.send(JSON.stringify(itemsResponse,null," "))

  app.get '/:locale', (req, res) ->
    locale = req.params.locale
    for l in apacroot.locales()
      if(l == locale)
        apachbridge.nodeLookup locale,getRootNodes(locale),["BrowseNodeInfo"],(err,nodeRawArray)=>
          if(err)
            res.redirect "/"
            return
          nodes = wrapper.wrapNode(nodeRawArray)
          res.render 'rootlist',{
            locale         : locale
            rootCategories : nodes
            title          : "QJITSU /#{locale}"
          }
          return
        return
    res.redirect "/"
    
  getRootNodes = (locale)->
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
    if(locale == "ES")
      return [
        1703496031,
        599371031,
        599392031,
        599386031,
        599365031,
        599368031,
        599374031,
        1748201031,
        599380031,
        599389031,
        599377031,
        818938031,
        599383031,
        1571263031
      ]
    if(locale == "FR")
      return [
        1571269031,
        193711031,
        672109031,
        590749031,
        206618031,
        215935031,
        57686031,
        409392,
        192420031,
        908827031,
        340859031,
        340862031,
        322088011,
        548014,
        69633011,
        301130,
        547972,
        213081031,
        60937031,
        301164,
        206442031,
        197859031,
        13910671,
        197862031,
        325615031,
        340856031
      ]
    if(locale == "IT")
      return [
        524016031,
        412610031,
        412607031,
        635017031,
        523998031,
        1571293031,
        818939031,
        411664031,
        433843031,
        412601031,
        1748204031,
        524010031,
        1571287031,
        524007031,
        524007031,
        412613031,
        524013031,
        412604031
      ]
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

    ids = []
    for category in apacroot.categories(locale)
      ids.push(apacroot.rootnode(locale,category))
    return ids
  
  app.get "/:locale/:nodeid", (req, res) ->  
    locale = req.params.locale
    nodeid = req.params.nodeid
    apachbridge.nodeLookup locale,[nodeid],["BrowseNodeInfo"],(err,result)->
      if (err)
        console.log('Error: ' + err + "\n")
        res.redirect "/#{locale}"
        return
      if (result.length == 0)
        console.log("Not found")
        res.redirect "/#{locale}"
        return
      node = new wrapper.Node(result[0])
      #logger.trace JSON.stringify(result[0],null," ")
      title = "/#{locale}"
      fromTop = node.AncestorsFromTop
      for Ancestor in fromTop[0]
        title = "#{title}/#{Ancestor.Name}"
      title = "#{title}/#{node.Name}"
      res.render 'index',{
        locale : locale
        data:node
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
      apachbridge.nodeLookup locale,prefetchIds,["BrowseNodeInfo"],(err,result)->
        #Do nothing
        
  app.use (err, req, res, next)->
    console.log err
    res.status(500)
    res.render('error/500')
      