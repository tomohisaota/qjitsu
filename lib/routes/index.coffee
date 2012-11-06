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
      locales:locales
    }

  app.get '/:locale', (req, res) ->
    locale = req.params.locale
    for l in apacroot.locales()
      if(l == locale)
        categories = apacroot.categories(locale)
        rootCategories = []
        for category in categories
          rootCategories.push {
            Name : category
            NodeId : apacroot.rootnode(locale,category)
          }
        res.render 'rootlist',{
          locale         : locale
          rootCategories : rootCategories
        }
        return
    res.redirect "/"
  
  app.get "/:locale/:nodeid", (req, res) ->  
    locale = req.params.locale
    nodeid = req.params.nodeid
    apachbridge.nodeLookupFull locale,[nodeid],(err,result)->
      if (err)
        console.log('Error: ' + err + "\n")
      logger.trace JSON.stringify(result[0],null," ")
      res.render 'index',{data:result[0]}