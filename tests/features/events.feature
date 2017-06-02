@events
Feature: Events

  Background:
    Given I am logged in as an admin
    And I navigate to "/events"

  Scenario: Submit a blank event form
    And I click on the create new event button
    And I create an event with name "" and summary ""
    Then I should see an invalid form

  Scenario: Submit an event with only a name
    When I click on the create new event button
    And I create an event with name "A test" and summary ""
    Then I should see content "A test"

  Scenario: Submit an event form with only a summary
    When I click on the create new event button
    And I create an event with name "" and summary "A summary"
    Then I should see an invalid form

  Scenario: Submit an event with a name and summary
    When I click on the create new event button
    And I create an event with name "A test" and summary "A summary"
    Then I should see content "A test"
    And I should see content "A summary"

  Scenario: Delete an existing event
    When I click on the create new event button
    And I create an event with name "A test" and summary "A summary"
    Then I navigate to "/events"
    And I delete the first item in the event list
    And I "confirm" deletion
    Then I should see a "success" notification
    And I should not see content "A test"

  Scenario: Cancel deleting an existing event
    When I click on the create new event button
    And I create an event with name "A test" and summary "A summary"
    Then I navigate to "/events"
    And I delete the first item in the event list
    And I "cancel" deletion
    Then I should not see content "EDIT EVENT DETAILS"
    And I should see content "A test"
