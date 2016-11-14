do ->
  'use strict'

  module.exports = ->
    url = require('url')

    @Before(() ->
      @server.call("reset")
      @server.call("createTestingAdmin")
    )

    @After(()  ->
      @server.call("reset")
    )

    @Given(/^I am on the site$/, () ->
      @client.url(url.resolve(process.env.ROOT_URL, '/'))
    )

    @Given(/^I am logged in as an admin$/, () ->
      if @client.isVisible("button.navbar-toggle")
        @client.click("button.navbar-toggle")
      @client.pause(1000)
      @client.click("a.withIcon[title='Sign In']")
      @client.pause(1000)
      @client.setValue("#at-field-email", "chimp@testing1234.com")
      @client.setValue("#at-field-password", "Pa55w0rd!")
      @browser.submitForm("#at-pwd-form")
    )

    @Given(/^I can go to the account form$/, () ->
      if @client.isVisible("button.navbar-toggle")
        @client.click("button.navbar-toggle")
      @client.waitForVisible("#admins-menu")
      @client.moveToObject("#admins-menu")
      @client.waitForVisible(".dropdown-menu.nav-dd")
      @client.click(".dropdown-menu.nav-dd li:first-child a")
      @client.waitForExist("#add-account")
    )

    @Then(/^I cannot submit a blank account form$/, () ->
      @browser.submitForm("#add-account")
      @client.waitForExist(".toast-error")
      expect(@client.isExisting(".toast-error")).toBe(true)
      @client.click("button.toast-close-button")
    )

    @Then(/^I can submit a form that has email "([^"]*)" and name "([^"]*)"$/, (address, profileName) ->
      initialLen = @client.elements(".container.content-block p").value.length
      @client.setValue("input[name='email']", address)
      @client.setValue("input[name='name']", profileName)
      @browser.submitForm("#add-account")
      @client.pause(2000)
      currentLen = @client.elements(".container.content-block p").value.length
      @client.waitForExist(".toast-success")
      @client.click("button.toast-close-button")
      expect(initialLen).not.toEqual(currentLen)
    )

    @Given(/^I can go to the event form$/, () ->
      if @client.isVisible("button.navbar-toggle")
        @client.click("button.navbar-toggle")
      @client.click("a=Tracked Events")
      @client.pause(2000)
      @client.click("a=Create New Event")
    )

    @Then(/^I can(not)? create an event with name "([^"]*)" and summary "([^"]*)"$/, (negated, name, summary) ->
      @client.setValue("#eventName", name)
      @client.setValue("#eventSummary", summary)
      @browser.submitForm("#add-event")
      @client.pause(1000)
      if negated
        expect(@client.isExisting(".toast-error")).toBe(true)
        @client.click("button.toast-close-button")
      else
        expect(@client.isExisting("h1=" + name)).toBe(true)
        if summary
          expect(@client.isExisting("p.abstract=" + summary)).toBe(true)
    )
