@incidents
Feature: Incident

  Background:
    And I am logged in as an admin

  Scenario: Add incident
    When I navigate to "/user-events"
    And I click the first item in the event list
    And I add an incident with count "100000001"
    Then I should see a "success" notification
    And I should see a scatter plot group with count "100000001"

  Scenario: Add suggested source and abandon changes
    When I navigate to "/user-events"
    And I click the first item in the event list
    And I add the first suggested event source
    And I add the first suggested incident
    Then I can "abandon" suggestions

  Scenario: Add suggested source and confirm changes
    When I navigate to "/user-events"
    And I click the first item in the event list
    And I add the first suggested event source
    And I add the first suggested incident
    Then I can "confirm" suggestions
