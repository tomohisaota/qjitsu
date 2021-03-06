express = require 'express'
stylus = require 'stylus'
routes = require './routes'
socketio = require 'socket.io'
log4js = require("log4js")

if(process.env.NODE_ENV == "production")
  log4js.setGlobalLogLevel("INFO")
else
  log4js.setGlobalLogLevel("TRACE")
  
app = express.createServer()
io = socketio.listen(app)

app.use express.logger {format: ':method :url :status :response-time ms'}
app.use express.bodyParser()
app.use express.methodOverride()
app.use require("connect-assets")(src : __dirname+"/assets")
app.set("views", __dirname + "/views")
app.set('view engine', 'jade')
app.use express.static(__dirname + '/public')
app.use app.router

# Routes
routes.loadRoute app

# Socket.IO
io.sockets.on 'connection', (socket) ->
  socket.emit 'hello',
    hello: 'says server'


port = process.env.PORT or 8080
app.listen port, -> 
  console.log "Listening on port " + port
