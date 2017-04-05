@documents
Feature: Documentss

  Background:
    Given I am logged in as an admin
    And I navigate to "/events"
    And I navigate to the first event

  Scenario: I add a custom document to an event
    When I click on the add document button
    And I create a document with a title of "Test Document", url of "http://www.promedmail.org/post/2579682", and datetime of now
    Then I should see content "Test Document"

  Scenario: I edit an existing document
    When I select the existing document
    Then I should not see content "Updated Title"
    Then I edit the existing document
    And I change the document title to "Updated Title" and datetime to now
    Then I should see content "Updated Title"

  Scenario: I delete an existing document
    When I select the existing document
    Then I delete the existing document
    And I "confirm" deletion
    Then I should see an empty documents table
