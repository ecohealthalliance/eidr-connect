@curatorInbox
Feature: Curator Inbox

  Background:
    Given I am logged in as an admin
    And I navigate to "/curator-inbox"

  Scenario: Add a new document to user added feed with link
    When I select the "User Added" feed
    Then I add a new test document with "link"
    Then I should see the content of the document
    And I should see accepted or rejected incidents

  Scenario: Add a new document to user added feed with text content
    When I select the "User Added" feed
    Then I add a new test document with "text content"
    Then I should see the content of the document
    And I should see accepted or rejected incidents
