do ->
  'use strict'

  module.exports = ->
    url = require('url')

    @Before(() ->
      @server.call("reset")
      @server.call("createTestingAdmin")
    )

    @After(()  ->
      @client.pause(2000)
      @client.click("#logOut")
      @client.pause(2000)
      @server.call("reset")
    )

    @Given(/^I am on the site$/, () ->
      @client.url(url.resolve(process.env.ROOT_URL, '/'))
    )

    @Given(/^I am logged in as an admin$/, () ->
      @client.waitForExist("a.withIcon[title='Sign In']")
      @client.click("a.withIcon[title='Sign In']")
      @client.pause(2000)
      @client.setValue("#at-field-email", "chimp@testing1234.com")
      @client.setValue("#at-field-password", "Pa55w0rd!")
      @browser.submitForm("#at-pwd-form")
      @client.pause(2000)
    )

    @Given(/^I can go to the account form$/, () ->
      @client.waitForExist("#logOut")
      @client.click("#admins-menu")
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
      @client.setValue("input[name='email']", address)
      @client.setValue("input[name='name']", profileName)
      @browser.submitForm("#add-account")
      @client.pause(3000)
      userList = @client.elements(".container.content-block p")
      @client.waitForExist(".toast-success")
      @client.click("button.toast-close-button")
      expect(userList.value.length).toEqual(2)
    )
