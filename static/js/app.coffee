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

  canvas_wrapper = document.querySelector('.canvas-wrapper')
  canvas_pdf = document.getElementById('canvas-pdf')
  canvas_pdf_context = canvas_pdf.getContext('2d')
  canvas_board = document.getElementById('canvas-board')
  canvas_board_context = canvas_board.getContext('2d')
  canvas_board_buffer = document.getElementById('canvas-board-buffer')
  canvas_board_buffer_context = canvas_board_buffer.getContext('2d')

  $scope.socket_io
  .on 'id', (data)->
    $scope.$apply ->
      $scope.id = data
  .on 'status', (status)->
    $scope.$apply ->
      $scope.status = status
      delete_ghost_users()
  .on 'mousePos', (data)->
    $timeout.cancel($scope.mouse_timeout[data.user_id])
    $scope.$apply ->
      data._active = true
      $scope.mouse_positions[data.user_id] = data
      $scope.mouse_timeout[data.user_id] = $timeout ->
        pos = $scope.mouse_positions[data.user_id]
        if pos
          pos._active = false
      , 3000
  .on 'drawPath', (data)->
    $scope.$apply ->
      if not $scope.status or not $scope.pdf or not $scope.scale
        return
      total_seg = data.path.length
      if total_seg == 0
        return
      scale = $scope.scale
      color = $scope.get_user(data.user_id).color
      canvas_board_context.lineWidth = scale
      canvas_board_context.strokeStyle = color
      canvas_board_context.beginPath()
      canvas_board_context.moveTo(data.path[0].x * scale, data.path[0].y * scale)
      i = 1
      prev_seg = data.path[0]
      while i < total_seg
        seg = data.path[i]
        canvas_board_context.bezierCurveTo((prev_seg.x + prev_seg.ox) * scale, (prev_seg.y + prev_seg.oy) * scale, (seg.x + seg.ix) * scale, (seg.y + seg.iy) * scale, seg.x * scale, seg.y * scale)
        prev_seg = seg
        i++
      canvas_board_context.stroke()
      canvas_board_context.closePath()
  .on 'refresh', ->
    $scope.$apply ->
      $scope.render()

  $scope.$watch 'status.file_id', (new_val)->
    $scope.show_home_menu = !new_val
    if !!new_val
      $scope.load_pdf('/pdf/'+new_val, $scope.status.page)
    else
      $scope.reset_pdf()

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
      
  $scope.reset_pdf = ->
    $scope.page = undefined
    $scope.pdf = undefined
    canvas_wrapper.style.width = '0px'
    canvas_wrapper.style.height = '0px'

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

  $scope.refresh = ->
    $scope.socket_io.emit 'refresh'

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
    paper.setup([viewport.width, viewport.height])

  $inputPDF = $('#input-pdf')
  $inputPDF.on 'change', ()->
    return if @files.length != 1
    sendFile(@files[0])
    @.value = ''

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

  draw_started = false
  draw_path = []

  draw_start = (e)->
    e.preventDefault()
    if not $scope.status or not $scope.pdf or not $scope.scale
      return
    draw_started = true
    if e.touches
      t = e.touches[0]
      px = t.pageX
      py = t.pageY
    else
      px = e.pageX
      py = e.pageY
    pos =
      x: (px - @offsetLeft) / $scope.scale
      y: (py - @offsetTop) / $scope.scale
    draw_path = [pos]
    canvas_board_buffer_context.lineWidth = $scope.scale
    canvas_board_buffer_context.strokeStyle = $scope.get_user($scope.id).color
    canvas_board_buffer_context.beginPath()
    canvas_board_buffer_context.moveTo(pos.x * $scope.scale, pos.y * $scope.scale)

  drawing = (e)->
    e.preventDefault()
    if not $scope.status or not $scope.pdf or not $scope.scale
      return
    if e.touches
      t = e.touches[0]
      px = t.pageX
      py = t.pageY
    else
      px = e.pageX
      py = e.pageY
    pos =
      x: (px - @offsetLeft)/ $scope.scale
      y: (py - @offsetTop) / $scope.scale
    $scope.socket_io.emit 'mousePosUpdate', pos
    if draw_started
      draw_path.push(pos)
      canvas_board_buffer_context.lineTo(pos.x * $scope.scale, pos.y * $scope.scale)
      canvas_board_buffer_context.clearRect(0, 0, canvas_board_buffer.width, canvas_board_buffer.height)
      canvas_board_buffer_context.stroke()

  draw_end = (e)->
    e.preventDefault()
    if not $scope.status or not $scope.pdf or not $scope.scale
      return
    canvas_board_buffer_context.closePath()
    canvas_board_buffer_context.clearRect(0, 0, canvas_board_buffer.width, canvas_board_buffer.height)
    draw_started = false
    $scope.socket_io.emit 'drawPath',
      path: optimize_path(draw_path)

  optimize_path = (path)->
    p = new paper.Path
      segments: path
    p.simplify(1.0)
    results = []
    total = p.segments.length
    for seg, i in p.segments
      data =
        x: seg.point.x
        y: seg.point.y
      if i > 0
        data.ix = seg.handleIn.x
        data.iy = seg.handleIn.y
      if i < total - 1
        data.ox = seg.handleOut.x
        data.oy = seg.handleOut.y
      results.push(data)
    return results

  $(canvas_wrapper)
  .on 'mousedown touchstart', draw_start
  .on 'mousemove touchmove', drawing
  .on 'mouseup touchend', draw_end

  $(document.body).on 'touchmove', (e)->
    e.preventDefault()

  $(window).on 'close', ->
    $scope.socket_io.close()
]