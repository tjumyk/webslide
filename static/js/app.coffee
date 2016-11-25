PDFJS.workerSrc = '/static/vendor/js/pdfjs/build/pdf.worker.js'

angular.module 'app', []

.controller 'rootController', ['$scope','$http', '$sce', '$timeout', 'util', ($scope, $http, $sce, $timeout, util)->
  $scope.app =
    name: 'Webslide'
    title: 'Webslide'
    copyright: '© Kelvin Miao, 2016'

  $scope.socket_io = io()
  $scope.show_home_menu = true
  $scope.host_mode = false
  $scope.mouse_positions = {}
  $scope.mouse_timeout = {}

  canvas_wrapper = document.getElementById('canvas-wrapper')
  canvas_pdf = document.getElementById('canvas-pdf')
  canvas_pdf_context = canvas_pdf.getContext('2d')
  canvas_board = document.getElementById('canvas-board')
  canvas_board_context = canvas_board.getContext('2d')

  $scope.socket_io.on 'id', (data)->
    $scope.$apply ->
      $scope.id = data

  $scope.socket_io.on 'status', (status)->
    # console.log status
    $scope.$apply ->
      $scope.status = status
      delete_ghost_users()

  $scope.socket_io.on 'mousePos', (data)->
    $timeout.cancel($scope.mouse_timeout[data.user_id])
    $scope.$apply ->
      data._active = true
      $scope.mouse_positions[data.user_id] = data
      $scope.mouse_timeout[data.user_id] = $timeout ->
        pos = $scope.mouse_positions[data.user_id]
        if pos
          pos._active = false
      , 3000

  $scope.$watch 'status.file_id', (new_val)->
    $scope.show_home_menu = !new_val
    if !!new_val
      $scope.load_pdf('/pdf/'+new_val, $scope.status.page)

  $scope.$watch 'status.page', (new_val)->
    return if not new_val or not $scope.pdf
    $scope.load_page(new_val)

  $scope.get_user = (uid)->
    return undefined  if !$scope.status
    for user in $scope.status.users
      if user.id == uid
        return user
    return undefined

  $scope.load_pdf = (url, page, callback)->
    $scope.pdf = undefined
    $scope.downloadProgress = 0
    PDFJS.getDocument(url, undefined , undefined , (progress)->
      if progress.total > 0
        $timeout ->
          if progress.loaded >= progress.total
            $scope.downloadProgress = undefined
          else
            $scope.downloadProgress = Math.round(100.0 * progress.loaded / progress.total)
    ).then (pdf)->
      $scope.pdf = pdf
      $scope.load_page(page, callback)
    , (data)->
      console.error(data)

  $scope.load_page = (page_num, callback)->
    return if not $scope.pdf
    $scope.page = undefined
    $scope.pdf.getPage(page_num).then (page)->
      $scope.page = page
      $scope.render()
    , (data)->
      console.error(data)

  $scope.toggle_fullscreen = ->
    util.toggleFullscreen()

  $scope.render = ->
    if not $scope.pdf or not $scope.page
      return
    viewport = $scope.page.getViewport(1.0)
    scale_w = document.body.clientWidth / viewport.width
    scale_h = document.body.clientHeight / viewport.height
    $scope.scale = Math.min(scale_w, scale_h)
    viewport = $scope.page.getViewport($scope.scale)
    canvas_wrapper.style.width = viewport.width + 'px'
    canvas_wrapper.style.height = viewport.height + 'px'
    canvas_wrapper.style.left = (document.body.clientWidth - viewport.width)/2 + 'px'
    canvas_wrapper.style.top = (document.body.clientHeight - viewport.height)/2 + 'px'
    $('canvas').each ->
      @width = viewport.width
      @height = viewport.height
    $scope.page.render
      canvasContext: canvas_pdf_context
      viewport: viewport

  $inputPDF = $('#input-pdf')
  $inputPDF.on 'change', ()->
    return if @files.length != 1
    sendFile(@files[0])

  $scope.startPresentation = ->
    $scope.uploadProgress = undefined
    $scope.host_mode = true
    $inputPDF.click()
    return
    
  delete_ghost_users = ->
    to_remove = []
    for uid of $scope.mouse_positions
      not_found = true
      for user in $scope.status.users
        if user.id == uid
          not_found = false
          break
      if not_found
        to_remove.push(uid)
    for uid in to_remove
      delete $scope.mouse_positions[uid]

  sendFile = (file) ->
    $timeout ->
      formData = new FormData()
      formData.append('pdf', file)
      formData.append('host', $scope.id)
      $.ajax
        type:'POST'
        url: '/upload-pdf'
        data:formData
        xhr: ->
          myXhr = $.ajaxSettings.xhr()
          if myXhr.upload
            myXhr.upload.addEventListener('progress',fileProgress, false)
          else
            console.warn('Failed to add file upload progress listener')
          return myXhr
        cache:false
        contentType: false
        processData: false
        success:(data)->
          console.log(data)
        error: (data)->
          console.error(data)

  fileProgress = (e)->
    if e.lengthComputable
      max = e.total
      current = e.loaded
      $scope.$apply ->
        if current == max
          $scope.uploadProgress = undefined
        else
          $scope.uploadProgress = 100.0 * current / max
    else
      console.warn('File upload progress is not computable')

  resizeCanvas = ->
    $timeout ->
      $scope.render()

  resizeCanvas()
  $(window). on 'resize', resizeCanvas
  $(document). on 'keydown', (e)->
    if e.keyCode == 37 or e.keyCode == 38
      $scope.load_prev_page()
    else if e.keyCode == 39 or e.keyCode == 40
      $scope.load_next_page()

  $scope.load_prev_page = ->
    if $scope.id != $scope.status.host
      return
    if not $scope.status or not $scope.pdf
      return
    page = $scope.status.page
    if page > 1
      $scope.status.page = page - 1
      $scope.socket_io.emit 'statusUpdate', $scope.status

  $scope.load_next_page = ->
    if $scope.id != $scope.status.host
      return
    if not $scope.status or not $scope.pdf
      return
    page = $scope.status.page
    if page < $scope.pdf.numPages
      $scope.status.page = page + 1
      $scope.socket_io.emit 'statusUpdate', $scope.status

  $(canvas_wrapper).on 'mousemove', (e)->
    if not $scope.status or not $scope.pdf or not $scope.scale
      return
    offset = $(@).offset()
    $scope.socket_io.emit 'mousePosUpdate',
      x: (e.pageX - offset.left)/ $scope.scale
      y: (e.pageY - offset.top) / $scope.scale

  $(canvas_wrapper).on 'touchmove', (e)->
    if not $scope.status or not $scope.pdf or not $scope.scale
      return
    t = e.touches[0]
    offset = $(@).offset()
    $scope.socket_io.emit 'mousePosUpdate',
      x: (t.pageX - offset.left) / $scope.scale
      y: (t.pageY - offset.top) / $scope.scale

  $(window).on 'close', ->
    $scope.socket_io.close()
]