do ->
  'use strict'

  module.exports = ->

    selectFirstEvent = (client) ->
      client.waitForVisible('.reactive-table tbody tr:first-child')
      elements = client.elements('.reactive-table tbody')
      if elements.value.length <= 0
        throw new Error('Curated Events table is empty')
      client.click('.reactive-table tbody tr:first-child')

    @When /^I click on the create new event button$/, ->
      @client.clickWhenVisible('.create-event')

    @When 'I toggle sorting on the "$column" column', (column)->
      @client.clickWhenVisible("th." + column)
      @client.pause(5000)

    @When /^I create an event with name "([^']*)" and summary "([^']*)"$/, (name, summary) ->
      @client.waitForVisible('#create-event-modal')
      @client.setValue('#eventName', name)
      @client.setValue('#eventSummary', summary)
      @client.click('#add-event-btn')
      @client.pause(100)

    @When /^I navigate to the first event$/, ->
      selectFirstEvent(@client)

    # @When /^I delete the first item in the event list$/, ->
    #   selectFirstEvent(@client)
    #   @client.clickWhenVisible('i.edit-event-details')
    #   @client.clickWhenVisible('.delete-event')

    @When /^I select the "([^']*)" tab$/, (tab) ->
      switch tab
        when 'estimated epi curves'
          @client.clickWhenVisible('.event nav ul li:nth-of-type(1) a')
        when 'incidents'
          @client.clickWhenVisible('.event nav ul li:nth-of-type(2) a')
        when 'affected areas'
          @client.clickWhenVisible('.event nav ul li:nth-of-type(3) a')
        when 'details'
          @client.clickWhenVisible('.event nav ul li:nth-of-type(4) ul li:first-of-type a')
        when 'references'
          @client.clickWhenVisible('.event nav ul li:nth-of-type(4) ul li:nth-of-type(2) a')

    @When /^I delete the event$/, ->
      @client.clickWhenVisible('.edit-event')
      @client.clickWhenVisible('.delete-event')
