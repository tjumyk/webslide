# WebSlide

![logo](static/image/logo-128.png)

WebSlide is a tiny multi-user online slide show website based on [node.js](https://nodejs.org/) and [WebSocket](https://developer.mozilla.org/zh-CN/docs/Web/API/WebSocket).
 
Currently, it is only an experimental project for ad-hoc usage only.

## Features

 - Support PDF slides (rendered by [PDF.js](https://mozilla.github.io/pdf.js/))
 - Synchronize the viewport of the presenter to all the watchers
 - Display the moving cursors of all the connected users
 - Display the drawing from all the connected users
    - optimize drawn paths with bezier curves 

## How to Run

 1. Install dependencies
 
   ```bash
   npm install
   ```

 2. Run server

   ```bash
   npm start 
   ```
