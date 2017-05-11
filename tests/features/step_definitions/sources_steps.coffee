do ->
  'use strict'

  module.exports = ->

    getTime = (date) ->
      hour = date.getHours()
      minutes = date.getMinutes()
      _minutes = if minutes < 10 then "0#{minutes}" else minutes
      _hour = switch hour
        when 0 then 12
        when hour > 12 then hour - 12
        else hour
      time = "#{_hour}:#{_minutes}"

    formatDate = (date) ->
      dateString = "#{date.getMonth() + 1}/#{date.getDate()}/#{date.getFullYear()}"

    getSourcesFromTable = (browser) ->
      browser.elements('#event-sources-table tbody tr')

    @When /^I click on the add document button$/, ->
      @client.pause(1000)
      @client.clickWhenVisible('.open-source-form-in-details')

    @When /^I create a document with a title of "([^']*)", url of "([^']*)", and datetime of now$/, (title, url) ->
      date = new Date()
      @client.waitForVisible('#add-source')
      @client.setValue('#title', title)
      @client.setValue('#article', url)
      @client.setValue('input[name=daterangepicker_start]', formatDate(date))
      @client.setValue('#publishTime', getTime(date))
      # Disable enhancement
      # @client.click('[for="enhance"]')
      @browser.scroll(0, 1000)
      @client.click('#event-source .save-source')

    @When /^I select the existing document$/, ->
      @client.clickWhenVisible('#event-sources-table tbody tr:first-child')

    @When /^I delete the existing document$/, ->
      @client.clickWhenVisible('.delete-source')

    @When /^I edit the existing document$/, ->
      @client.clickWhenVisible('.edit-source')

    @When /^I change the document title to "([^']*)" and datetime to now$/, (title) ->
      date = new Date()
      @client.waitForVisible('#add-source')
      @client.setValue('#title', title)
      @client.setValue('input[name=daterangepicker_start]', formatDate(date))
      @client.setValue('#publishTime', getTime(date))
      @browser.scroll(0, 1000)
      @client.click('#event-source .save-source-edit')

    @Then /^I see the new document in the document table$/, ->
      if getSourcesFromTable(@browser).value.length <= 1
        throw new Error('New document is not in the document table')

    @Then /^I should see an empty documents table$/, ->
      @browser.waitForVisible('#event-sources-table tbody tr', 10000, true)
