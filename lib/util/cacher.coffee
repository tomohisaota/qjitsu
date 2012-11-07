logger = require("log4js").getLogger("util.cacher")

async = require("async")

class Cacher
  cache : null
  
  constructor: ->
    @cache = {}
  
  set : (key,value,ttl,cb)=>
    logger.trace("set(#{key},#{value},#{ttl},cb)")
    @cache[key] = {
      expires : new Date().getTime() + ttl
      value : value
    }
    cb()
    
  get : (key,cb)=>
    cache = @cache[key] || null
    unless(cache)
      logger.trace("get(#{key},cb) -> miss")
      return cb(null)
    if(new Date().getTime() > cache.expires)
      logger.trace("get(#{key},cb) -> expired")
      return cb(null)
    logger.trace("get(#{key},cb) -> #{cache.value}")
    cb(null,cache.value)
  
  opSet : (key,value,ttl)=>
    return (cb) => 
      @set(key,value,ttl,cb)

  opGet : (key)=>
    return (cb) => 
      @get(key,cb)
    
  mset : (valueMap,ttl,cb)=>
    logger.trace("mset(#{valueMap},#{ttl},cb)")
    ops = []
    for key,value of valueMap
      ops.push(@opSet(key,value,ttl))
    async.parallel ops,(err,result)=>
      if(err)
        return cb(err)
      return cb(null)
    
  mget : (keys,cb)=>
    logger.trace("mget(#{keys},cb)")
    ops = []
    for key in keys
      ops.push(@opGet(key))
    async.parallel ops,(err,result)=>
      if(err)
        return cb(err)
      valueMap = {}
      for i in [0..(keys.length-1)]
        continue unless(result[i])
        valueMap[keys[i]] = result[i]
      return cb(null,valueMap)
    
module.exports = new Cacher()