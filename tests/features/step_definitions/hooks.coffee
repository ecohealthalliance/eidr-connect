do ->
  'use strict'

  module.exports = ->
    url = require('url')

    commandsAdded = false

    @Before ->
      if not commandsAdded
        @client.addCommand "clickWhenVisible", (selector)->
          @waitForVisible(selector)
          @click(selector)
        commandsAdded = true
      console.log 'Results of load method:' + JSON.stringify(@server.call('load'), null, 4)
      @client.url(url.resolve(process.env.ROOT_URL, '/'))

    @After ->
      @server.call('reset')
