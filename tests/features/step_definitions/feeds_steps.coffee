do ->
  'use strict'

  module.exports = ->
    url = require('url')

    @Then /^I select feeds from the settings dropdown$/, ->
      @client.moveToObject('.dropdown')
      @client.clickWhenVisible('.feeds')

    @Then /^I add the feed "([^"]*)"$/, (feed) ->
      @client.setValue('input[name=feedUrl]', feed)
      @client.click('.add-feed .btn-primary')

    @Then /^I delete the feed$/, ->
      @client.moveToObject('.feeds--list:first-child')
      @client.clickWhenVisible('.delete')
