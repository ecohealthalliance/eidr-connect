do ->
  'use strict'

  module.exports = ->

    DOCUMENT_LINK = 'http://www.promedmail.org/post/5018201'
    DOCUMENT_TEXT = """
      US Deer Antler Ex and Imp, of Los Angeles, CA is recalling a variety of herbal teas prepared on [its] premises between 1 March and 30 April 2017 in cooperation with an inspection made by the California Department of Public Health. The aforementioned herbal teas, especially those with low-acidity held at room temperature, were not produced according to approved guideline, making them susceptible to contamination by _Clostridium botulinum_.

      Below are the product descriptions:
      Products / Packaging / Cases
      Herbal Tea Variety Batches prepared on the premises between 1 Mar 2017 and 30 Apr 2017 / 120 mL per pouch / 40 pouches per case

      The herbal teas were distributed to individual customers and acupuncturists in California, Florida, Illinois, Maryland, North Carolina, Texas, and Virginia.

      Symptoms of _Clostridium botulinum_ typically begin with blurred or double vision followed by trouble speaking, swallowing; and progression to muscle weakness starting in the upper body, moving downward. Botulism can lead to life-threatening paralysis of breathing muscles requiring support with a breathing machine (ventilator) and intensive care. http://www.cdph.ca.gov/HealthInfo/discond/Pages/Botulism.aspx
      People experiencing these symptoms who have recently consumed these herbal teas should seek immediate medical attention.

      In its ongoing cooperation with the California Department of Public Health, US Deer Antler Ex and Imp, Inc has immediately segregated its entire inventory of herbal tea varieties, and is notifying consumers and customers not to consume potentially-contaminated product.

      Furthermore, US Deer Antler Ex and Imp Inc is voluntarily recalling all varieties of general herbal teas prepared on site in the period of 1 March to 30 April 2017 to ensure consumer safety. Consumers in possession of these products are to stop consumption and return unconsumed product to their original place of purchase.

      US Deer Antler Ex and Imp, Inc will be sending recall notices to all of its direct customers. Please contact Joong W Park (323) 735-9665 for further information.
    """

    @When /^I select the "([^"]*)" feed$/, (feedName) ->
      if feedName is 'User Added'
        @client.waitForVisible('.curator-inbox--feed-selector')
        @client
          .element('.curator-inbox--feed-selector')
          .selectByValue('userAdded')

    @When /^I add a new test document with "([^"]*)"$/, (sourceType) ->
      @client.clickWhenVisible('.add-document')
      @client.waitForVisible('#add-source')
      if sourceType is 'link'
        @client.setValue('#article', DOCUMENT_LINK)
      else
        @client.click('[href="#text"]')
        @client.waitForVisible('#content')
        @client.setValue('#content', DOCUMENT_TEXT)
      @client.setValue('#title', 'Test Article')
      @client.clickIfVisible('.add-publish-date .btn')
      @client.setValue('#publishTime', '12:00 PM')
      @client.pause(3000)
      @client.click('.save-source')

    @Then /^I should see the content of the document$/, ->
      @client.waitForExist('.selectable-content')

    @Then /^I should see accepted or rejected incidents$/, ->
      @client.waitForExist('.incident-table tbody tr')
