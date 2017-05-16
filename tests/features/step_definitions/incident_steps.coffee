do ->
  'use strict'

  module.exports = ->

    scrollWithinModal = (client, selector, element, padding) ->
      client.execute (selector, element, padding) ->
        offset = $(element).first().offset()
        $(selector).scrollTop(offset.top + padding)
      , selector, element, padding
    # workaround for https://github.com/ariya/phantomjs/issues/13896
    setCalcHeight = (client, selector) ->
      client.execute (selector) ->
        height = $(window).height() - 236
        $(selector).css({height: "#{height}px"})
      , selector

    firstEvent = '.reactive-table tbody tr:first-child'

    @When /^I click the first item in the event list$/, ->
      @client.clickWhenVisible(firstEvent)
      @client.pause(1000)

    @When /^I add an incident with count "([^']*)"$/, (count) ->
      if not @client.waitForVisible(firstEvent)
        throw new Error('Event Incidents table is empty')
      @client.click('button.open-incident-form-in-details')
      # article URL
      @client.clickWhenVisible('span[aria-labelledby="select2-articleSource-container"]')
      @client.clickWhenVisible('#select2-articleSource-results li:first-child')
      # Location
      @client.setValue('input.select2-search__field', 'f')
      @client.clickWhenVisible('.select2-results__option--highlighted')
      # Status
      @client.click('label[for="suspected"]')
      # Type
      @client.click('label[for="cases"]')
      # Count
      @client.waitForVisible('input[name="count"]')
      @client.setValue('input[name="count"]', count)
      # Submit
      @client.click('button.save-incident[type="button"]')

    @When /^I should see a scatter plot group with count "([^']*)"$/, (count) ->
      @client.pause(2000)
      selector = "[id*=\":#{count}:false\"]"
      groups = @client.elements(selector)
      if groups.value.length != 1
        throw new Error('ScatterPlot Group is empty')

    @When /^I add the first suggested event document$/, ->
      @client.clickWhenVisible('.open-source-form-in-details')
      @client.waitForVisible('#event-source')
      @client.clickWhenVisible('#suggested-articles li:first-child')
      @client.setValue('input[name="publishTime"]', '12:00 PM')
      @client.click('button.save-source[type="button"]')

    @When /^I add the first suggested incident$/, ->
      # SuggestedIncidentsModal
      @client.waitForVisible('.suggested-annotated-content')
      if @client.isVisible('div.warn')
        text = @client.getText('div.warn')
        assert.equal(text.trim(), 'No incidents could be automatically extracted from the document.')
        @client.pause(2000)
        return true
      if @client.isVisible('span.annotation.annotation-text')
        scrollWithinModal(@client,
            '#suggested-locations-form',
            'span.annotation.annotation-text', -200)
        @client.clickWhenVisible('span.annotation.annotation-text')
        # SuggestedIncidentModal
        @client.waitForVisible('#suggestedIncidentModal div.modal-footer')
        scrollWithinModal(@client, '#suggestedIncidentModal',
            'button.save-modal[type="button"]', -200)
        @client.clickWhenVisible('button.save-modal[type="button"]')
        @client.pause(2000)
        return true
      throw new Error 'There was a problem loading suggested incidents.'

    @Then /^I can "([^"]*)" suggestions$/, (action) ->
      setCalcHeight(@client, '.suggested-incidents-wrapper')
      if action is 'abandon'
        @client.clickWhenVisible('button.confirm-close-modal[type="button"]')
        # confirm close modal
        @client.waitForVisible('#cancelConfirmationModal')
        @client.click('button.confirm[type="button"]')
        return true
      # get the original number of incidents before button has been clicked
      elements = @client.elements('div.count :first-child')
      try
        expectedNumber = parseInt(@client.elementIdText(elements.value[0].ELEMENT).value, 10) + 1
      catch
        throw new Error 'Cound not get actual number of incidents.'
      # click add-suggestions button
      @client.clickWhenVisible('#add-suggestions')
      @client.pause(2000)
      # get the actual number of incidents after button has been clicked
      elements = @client.elements('div.count :first-child')
      try
        actualNumber = parseInt(@client.elementIdText(elements.value[0].ELEMENT).value, 10)
      catch
        throw new Error 'Cound not get actual number of incidents.'
      assert.equal(expectedNumber, actualNumber)

    @Then 'I extract incidents from the url "$url"', (url) ->
      @client.clickWhenVisible('[href="#web"]')
      @client.waitForVisible(".submit-url")
      @client.setValue('.submit-url', url)
      @client.click('#submit-button')
      @client.pause(5000)
      @client.waitForVisible('.suggested-annotated-content')

    @Then 'I open the first incident', ->
      if @client.isVisible('.incident-table-tab')
        @client.click('.incident-table-tab')
      @client.clickWhenVisible('.incident-report')
      @client.waitForVisible('[name="count"]')

    @Then 'I set the count to "$count"', (count)->
      @client.setValue('[name="count"]', count)

    @Then 'I accept the incident', ->
      @client.clickWhenVisible('.save-modal')
      @client.pause(1000)

    @Then 'the first incident should have a count of "$count"', (count)->
      text = @client.getText('.incident-report')
      assert.ok(text[0].indexOf(count) > 0)
