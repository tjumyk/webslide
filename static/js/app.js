// Generated by CoffeeScript 1.10.0
(function() {
  PDFJS.workerSrc = '/static/vendor/js/pdfjs/build/pdf.worker.js';

  angular.module('app', []).controller('rootController', [
    '$scope', '$http', '$sce', '$timeout', 'util', function($scope, $http, $sce, $timeout, util) {
      var $inputPDF, canvas_board, canvas_board_context, canvas_pdf, canvas_pdf_context, canvas_wrapper, delete_ghost_users, fileProgress, resizeCanvas, sendFile;
      $scope.app = {
        name: 'Webslide',
        title: 'Webslide',
        copyright: '© Kelvin Miao, 2016'
      };
      $scope.socket_io = io();
      $scope.show_home_menu = true;
      $scope.host_mode = false;
      $scope.mouse_positions = {};
      $scope.mouse_timeout = {};
      canvas_wrapper = document.getElementById('canvas-wrapper');
      canvas_pdf = document.getElementById('canvas-pdf');
      canvas_pdf_context = canvas_pdf.getContext('2d');
      canvas_board = document.getElementById('canvas-board');
      canvas_board_context = canvas_board.getContext('2d');
      $scope.socket_io.on('id', function(data) {
        return $scope.$apply(function() {
          return $scope.id = data;
        });
      });
      $scope.socket_io.on('status', function(status) {
        return $scope.$apply(function() {
          $scope.status = status;
          return delete_ghost_users();
        });
      });
      $scope.socket_io.on('mousePos', function(data) {
        $timeout.cancel($scope.mouse_timeout[data.user_id]);
        return $scope.$apply(function() {
          data._active = true;
          $scope.mouse_positions[data.user_id] = data;
          return $scope.mouse_timeout[data.user_id] = $timeout(function() {
            var pos;
            pos = $scope.mouse_positions[data.user_id];
            if (pos) {
              return pos._active = false;
            }
          }, 3000);
        });
      });
      $scope.$watch('status.file_id', function(new_val) {
        $scope.show_home_menu = !new_val;
        if (!!new_val) {
          return $scope.load_pdf('/pdf/' + new_val, $scope.status.page);
        } else {
          return $scope.reset_pdf();
        }
      });
      $scope.$watch('status.page', function(new_val) {
        if (!new_val || !$scope.pdf) {
          return;
        }
        return $scope.load_page(new_val);
      });
      $scope.get_user = function(uid) {
        var i, len, ref, user;
        if (!$scope.status) {
          return void 0;
        }
        ref = $scope.status.users;
        for (i = 0, len = ref.length; i < len; i++) {
          user = ref[i];
          if (user.id === uid) {
            return user;
          }
        }
        return void 0;
      };
      $scope.load_pdf = function(url, page, callback) {
        $scope.pdf = void 0;
        $scope.downloadProgress = 0;
        return PDFJS.getDocument(url, void 0, void 0, function(progress) {
          if (progress.total > 0) {
            return $timeout(function() {
              if (progress.loaded >= progress.total) {
                return $scope.downloadProgress = void 0;
              } else {
                return $scope.downloadProgress = Math.round(100.0 * progress.loaded / progress.total);
              }
            });
          }
        }).then(function(pdf) {
          $scope.pdf = pdf;
          return $scope.load_page(page, callback);
        }, function(data) {
          return console.error(data);
        });
      };
      $scope.reset_pdf = function() {
        $scope.page = void 0;
        $scope.pdf = void 0;
        canvas_wrapper.style.width = '0px';
        return canvas_wrapper.style.height = '0px';
      };
      $scope.load_page = function(page_num, callback) {
        if (!$scope.pdf) {
          return;
        }
        $scope.page = void 0;
        return $scope.pdf.getPage(page_num).then(function(page) {
          $scope.page = page;
          return $scope.render();
        }, function(data) {
          return console.error(data);
        });
      };
      $scope.toggle_fullscreen = function() {
        return util.toggleFullscreen();
      };
      $scope.render = function() {
        var scale_h, scale_w, viewport;
        if (!$scope.pdf || !$scope.page) {
          return;
        }
        viewport = $scope.page.getViewport(1.0);
        scale_w = document.body.clientWidth / viewport.width;
        scale_h = document.body.clientHeight / viewport.height;
        $scope.scale = Math.min(scale_w, scale_h);
        viewport = $scope.page.getViewport($scope.scale);
        canvas_wrapper.style.width = viewport.width + 'px';
        canvas_wrapper.style.height = viewport.height + 'px';
        canvas_wrapper.style.left = (document.body.clientWidth - viewport.width) / 2 + 'px';
        canvas_wrapper.style.top = (document.body.clientHeight - viewport.height) / 2 + 'px';
        $('canvas').each(function() {
          this.width = viewport.width;
          return this.height = viewport.height;
        });
        return $scope.page.render({
          canvasContext: canvas_pdf_context,
          viewport: viewport
        });
      };
      $inputPDF = $('#input-pdf');
      $inputPDF.on('change', function() {
        if (this.files.length !== 1) {
          return;
        }
        sendFile(this.files[0]);
        return this.value = '';
      });
      $scope.startPresentation = function() {
        $scope.uploadProgress = void 0;
        $scope.host_mode = true;
        $inputPDF.click();
      };
      delete_ghost_users = function() {
        var i, j, len, len1, not_found, ref, results, to_remove, uid, user;
        to_remove = [];
        for (uid in $scope.mouse_positions) {
          not_found = true;
          ref = $scope.status.users;
          for (i = 0, len = ref.length; i < len; i++) {
            user = ref[i];
            if (user.id === uid) {
              not_found = false;
              break;
            }
          }
          if (not_found) {
            to_remove.push(uid);
          }
        }
        results = [];
        for (j = 0, len1 = to_remove.length; j < len1; j++) {
          uid = to_remove[j];
          results.push(delete $scope.mouse_positions[uid]);
        }
        return results;
      };
      sendFile = function(file) {
        return $timeout(function() {
          var formData;
          formData = new FormData();
          formData.append('pdf', file);
          formData.append('host', $scope.id);
          return $.ajax({
            type: 'POST',
            url: '/upload-pdf',
            data: formData,
            xhr: function() {
              var myXhr;
              myXhr = $.ajaxSettings.xhr();
              if (myXhr.upload) {
                myXhr.upload.addEventListener('progress', fileProgress, false);
              } else {
                console.warn('Failed to add file upload progress listener');
              }
              return myXhr;
            },
            cache: false,
            contentType: false,
            processData: false,
            success: function(data) {
              return console.log(data);
            },
            error: function(data) {
              return console.error(data);
            }
          });
        });
      };
      fileProgress = function(e) {
        var current, max;
        if (e.lengthComputable) {
          max = e.total;
          current = e.loaded;
          return $scope.$apply(function() {
            if (current === max) {
              return $scope.uploadProgress = void 0;
            } else {
              return $scope.uploadProgress = 100.0 * current / max;
            }
          });
        } else {
          return console.warn('File upload progress is not computable');
        }
      };
      resizeCanvas = function() {
        return $timeout(function() {
          return $scope.render();
        });
      };
      resizeCanvas();
      $(window).on('resize', resizeCanvas);
      $(document).on('keydown', function(e) {
        if (e.keyCode === 37 || e.keyCode === 38) {
          return $scope.load_prev_page();
        } else if (e.keyCode === 39 || e.keyCode === 40) {
          return $scope.load_next_page();
        }
      });
      $scope.load_prev_page = function() {
        var page;
        if ($scope.id !== $scope.status.host) {
          return;
        }
        if (!$scope.status || !$scope.pdf) {
          return;
        }
        page = $scope.status.page;
        if (page > 1) {
          $scope.status.page = page - 1;
          return $scope.socket_io.emit('statusUpdate', $scope.status);
        }
      };
      $scope.load_next_page = function() {
        var page;
        if ($scope.id !== $scope.status.host) {
          return;
        }
        if (!$scope.status || !$scope.pdf) {
          return;
        }
        page = $scope.status.page;
        if (page < $scope.pdf.numPages) {
          $scope.status.page = page + 1;
          return $scope.socket_io.emit('statusUpdate', $scope.status);
        }
      };
      $(canvas_wrapper).on('mousemove', function(e) {
        var offset;
        if (!$scope.status || !$scope.pdf || !$scope.scale) {
          return;
        }
        offset = $(this).offset();
        return $scope.socket_io.emit('mousePosUpdate', {
          x: (e.pageX - offset.left) / $scope.scale,
          y: (e.pageY - offset.top) / $scope.scale
        });
      });
      $(canvas_wrapper).on('touchmove', function(e) {
        var offset, t;
        if (!$scope.status || !$scope.pdf || !$scope.scale) {
          return;
        }
        t = e.touches[0];
        offset = $(this).offset();
        return $scope.socket_io.emit('mousePosUpdate', {
          x: (t.pageX - offset.left) / $scope.scale,
          y: (t.pageY - offset.top) / $scope.scale
        });
      });
      return $(window).on('close', function() {
        return $scope.socket_io.close();
      });
    }
  ]);

}).call(this);

//# sourceMappingURL=app.js.map
