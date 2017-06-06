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
        @client.addCommand "clickIfVisible", (selector)->
          if @isVisible(selector)
            @click(selector)
        commandsAdded = true
      @server.call('load')
      @client.url(url.resolve(process.env.ROOT_URL, '/'))

    @After ->
      @server.call('reset')
