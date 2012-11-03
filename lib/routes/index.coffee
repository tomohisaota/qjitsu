apacroot = require("apacroot")

exports.index = (req, res) ->
  res.render 'index'

OperationHelper = require('apac').OperationHelper
opHelper = new OperationHelper {
    awsId:     "AKIAIMMETNJCUITLGQSA"
    awsSecret: "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"
    assocId:   'ilovegwt-22'
    endPoint:  apacroot.endpoint("JP")
}

exports.popular = (req, res) ->
  res.contentType('application/json')
  opHelper.execute 'ItemSearch', {
      'SearchIndex': 'All',
      'Keywords': 'car',
      'ResponseGroup': 'Medium'
  }, (err, results)->
      if (err)
        console.log('Error: ' + err + "\n")
      console.log JSON.stringify(results,null," ")
      res.contentType('application/json; charset=utf-8')
      res.send(JSON.stringify(results.ItemSearchResponse.Items[0],null," "))


exports.browseNode = (req, res) ->
  res.contentType('application/json')
  opHelper.execute 'BrowseNodeLookup', {
      'BrowseNodeId': apacroot.rootnode("JP","Books")#,
      #'ResponseGroup': 'TopSellers'
  }, (err, results)->
      if (err)
        console.log('Error: ' + err + "\n")
      console.log JSON.stringify(results,null," ")
      res.contentType('application/json; charset=utf-8')
      res.send(JSON.stringify(results,null," "))
