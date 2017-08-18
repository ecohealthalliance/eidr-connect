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
    Then I navigate to the first event
    Then I select the "details" tab
    Then I should see content "summary"
    Then I delete the event
    And I "confirm" deletion
    Then I should see a "success" notification
    And I should not see content "A test"

  Scenario: Cancel deleting an existing event
    When I click on the create new event button
    And I create an event with name "A test" and summary "A summary"
    Then I navigate to "/events"
    Then I navigate to the first event
    Then I select the "details" tab
    Then I delete the event
    And I "cancel" deletion
    Then I should not see content "EDIT EVENT DETAILS"
    And I should see content "A test"

  Scenario: Filter event properties individually
    When I navigate to the first event
    And I select the "incidents" tab
    And I add "4" incidents with dates in the past
    Then I should see "5" incidents
    Then I filter by a date range of two weeks ago to today
    Then I should see "2" incidents
    Then I clear event filters
    Then I filter by "cases"
    Then I should see "4" incidents
    Then I clear event filters
    Then I filter by "deaths"
    Then I should see "1" incidents
    Then I clear event filters
    Then I filter by "confirmed"
    Then I should see "2" incidents
    Then I clear event filters
    Then I filter by the first location in the list
    Then I should see "4" incidents
    Then I clear event filters
    Then I filter by "travelRelated"
    Then I should see "1" incidents
    Then I clear event filters
    Then I should see "5" incidents
