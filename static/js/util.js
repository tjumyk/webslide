// Generated by CoffeeScript 1.10.0
(function() {
  angular.module('app').factory('util', [
    function() {
      var service;
      service = {
        formatResponseError: function(response) {
          if (!!response.data && !!response.data.error) {
            return response.data.error;
          } else if (response.status === -1) {
            return "Connection Aborted!";
          } else {
            return '[' + response.status + '] ' + response.statusText;
          }
        },
        formatDate: function(dateString) {
          return moment(dateString).format('LLL');
        },
        prettyJSON: function(json) {
          return JSON.stringify(eval(json), null, 4);
        },
        toggleFullscreen: function() {
          var elem;
          if (!document.fullscreenElement && !document.mozFullScreenElement && !document.webkitFullscreenElement) {
            elem = document.documentElement;
            if (elem.requestFullscreen) {
              return elem.requestFullscreen();
            } else if (elem.mozRequestFullScreen) {
              return elem.mozRequestFullScreen();
            } else if (elem.webkitRequestFullscreen) {
              return elem.webkitRequestFullscreen();
            }
          } else {
            if (document.cancelFullScreen) {
              return document.cancelFullScreen();
            } else if (document.mozCancelFullScreen) {
              return document.mozCancelFullScreen();
            } else if (document.webkitCancelFullScreen) {
              return document.webkitCancelFullScreen();
            }
          }
        }
      };
      return service;
    }
  ]);

}).call(this);

//# sourceMappingURL=util.js.map
