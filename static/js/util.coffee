angular.module('app').factory 'util', [->
  service =
    formatResponseError: (response)->
      if !!response.data and !!response.data.error
        return response.data.error
      else if response.status == -1
        return "Connection Aborted!"
      else
        return '[' + response.status + '] ' + response.statusText
    formatDate: (dateString)->
      return moment(dateString).format('LLL')
    prettyJSON: (json)->
      JSON.stringify(eval(json), null, 4)
    toggleFullscreen: ->
      if !document.fullscreenElement and !document.mozFullScreenElement and !document.webkitFullscreenElement
        elem = document.documentElement
        if elem.requestFullscreen
          elem.requestFullscreen()
        else if elem.mozRequestFullScreen
          elem.mozRequestFullScreen()
        else if elem.webkitRequestFullscreen
          elem.webkitRequestFullscreen()
      else
        if document.cancelFullScreen
          document.cancelFullScreen()
        else if document.mozCancelFullScreen
          document.mozCancelFullScreen()
        else if document.webkitCancelFullScreen
          document.webkitCancelFullScreen()
  return service
]
