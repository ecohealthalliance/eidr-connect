do ->
  'use strict'

  module.exports = ->
    url = require('url')

    @Then /^I click the first event in the list$/, ->
      @client.clickWhenVisible('.map-event-list li:first-child')

    @Then /^I click on a map marker$/, ->
      @client.clickWhenVisible('.map-marker')
