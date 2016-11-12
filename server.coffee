express = require('express')
app = express()
http = require('http').Server(app)
io = require('socket.io')(http)
multer  = require('multer')
upload = multer({ dest: 'uploads/' })

port = 8077
status = {
  file_id: undefined
  host: undefined
  started: false
  page: undefined
  users: []
}
app.use('/static', express.static('static'))

app.get '/', (req, res)->
  res.sendFile(__dirname + '/static/index.html')

app.get '/pdf/:file_id', (req, res)->
  res.sendFile(__dirname + '/uploads/' + req.params.file_id)

app.post '/upload-pdf', upload.single('pdf'), (req, res)->
  res.send('File uploaded: ' + req.file.originalname)
  status.started = true
  status.file_id = req.file.filename
  status.page = 1
  status.host = req.body.host
  io.emit 'status', status

io.on 'connection', (socket)->
  console.log('user connected: ' + socket.id)
  add_user(socket)
  socket.emit 'id', socket.id
  io.emit 'status', status

  socket.on 'disconnect', ->
    console.log('user disconnected: ' + socket.id)
    remove_user(socket)
    io.emit 'status', status

  socket.on 'statusUpdate', (data)->
    status = data
    io.emit 'status', status

  socket.on 'mousePosUpdate', (data)->
    data.user_id = socket.id
    io.emit 'mousePos', data
      
add_user = (socket)->
  for user in status.users
    if user.id == socket.id
      return
  status.users.push
    id: socket.id
    address: socket.conn.remoteAddress

remove_user = (socket)->
  to_remove = undefined
  for user, i in status.users
    if user.id == socket.id
      to_remove = i
      break
  if to_remove
    status.users.splice(to_remove, 1)

http.listen port, ->
  console.log('listening on *:' + port)



