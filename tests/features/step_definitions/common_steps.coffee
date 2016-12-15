do ->
  'use strict'

  module.exports = ->
    url = require('url')

    @When /^I navigate to "([^"]*)"$/, (relativePath) ->
      @client.pause(500)
      @client.url(url.resolve(process.env.ROOT_URL, relativePath))

    @Given /^I am logged in as an admin$/, ->
      if @client.isVisible('button.navbar-toggle')
        @client.click('button.navbar-toggle')
      @client.pause(1000)
      if @client.isExisting('#logOut')
        return
      @client.click('a.withIcon[title="Sign In"]')
      @browser.waitForVisible('#at-field-email')
      @client.setValue('#at-field-email', 'chimp@testing1234.com')
      @client.setValue('#at-field-password', 'Pa55w0rd!')
      @client.submitForm('#at-pwd-form')
      @client.waitForExist('#logOut')

    @When /^I open the settings dropdown$/, (relativePath) ->
      if @client.isVisible('button.navbar-toggle')
        @client.click('button.navbar-toggle')
      @browser.waitForVisible('.dropdown')
      @client.moveToObject('.dropdown-toggle-nav')

    @Then /^I should( not)? see content "([^"]*)"$/, (shouldNot, text) ->
      @client.pause 2000 # Give Blaze enough time to populate the <body>
      @client.getText 'body', (error, visibleText) ->
        match = visibleText?.toString().match(text)
        if shouldNot
          assert.notOk(match)
        else
          assert.ok(match)

    @Then /^I should( not)? see a "([^"]*)" toast$/, (noToast, type) ->
      @client.waitForVisible('.toast')
        # This causes a warning if no toast is visible
      toastClasses = @client.getAttribute('.toast', 'class')
      match = toastClasses?.match(type)
      if noToast
        assert.ok(not match)
      else
        assert.ok(match)

    @Then /^I "([^"]*)" deletion$/, (action) ->
      if action is 'cancel'
        @client.click('.cancel')
      else
        @client.click('.delete')