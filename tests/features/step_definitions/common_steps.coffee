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
      @client.click('#at-pwd-form .submit')
      @client.waitForExist('#logOut')

    @When /^I open the settings dropdown$/, (relativePath) ->
      if @client.isVisible('button.navbar-toggle')
        @client.click('button.navbar-toggle')
      @browser.waitForVisible('.dropdown')
      @client.moveToObject('.dropdown-toggle-nav')

    @Then /^I should( not)? see content "([^"]*)"$/, (shouldNot, text) ->
      @client.pause(2000) # Give Blaze enough time to populate the <body>
      @client.getText 'body', (error, visibleText) ->
        match = visibleText?.toString().match(text)
        if shouldNot
          assert.notOk(match)
        else
          assert.ok(match)

    @Then /^I should( not)? see a "([^"]*)" notification$/, (shouldNot, type) ->
      # Types: success, failure, warning
      @client.waitForVisible('.notification')
      notifyClasses = @client.getAttribute('.notification', 'class')
      match = notifyClasses?.match(type)
      if shouldNot
        assert.ok(not match)
      else
        assert.ok(match)

    @Then /^I "([^"]*)" deletion$/, (action) ->
      if action is 'cancel'
        @client.clickWhenVisible('.cancel')
      else
        @client.clickWhenVisible('.confirm-deletion')

    @Then /^I should see an invalid form$/, ->
      invalidInputCount = @client.elements('.parsley-error').value.length
      if not invalidInputCount
        throw new Error('The form is invalid when required inputs are empty')

    @Then /^I close the "([^"]*)" modal$/, (modal) ->
      @browser.scroll(0, 0)
      @client.clickWhenVisible("#{modal} .close-modal")

    @Then /^I dismiss the active notification$/, ->
      @client.clickWhenVisible('.notification')
      # Wait for notification to animate off-canvas
      @client.pause(500)
