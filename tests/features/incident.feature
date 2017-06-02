@incidents
Feature: Incident

  Background:
    And I am logged in as an admin

  Scenario: Add incident report
    When I navigate to "/events"
    And I click the first item in the event list
    And I add an incident with count "100000001"
    Then I should see a "success" notification
    And I should see a scatter plot group with count "100000001"

  Scenario: Edit an incident report
    When I navigate to "/events"
    And I click the first item in the event list
    And I click the first incident
    When I open the edit incident report modal
    Then I change the incident "location" to "Earth"
    And I change the incident "deaths" to "1000"
    Then I save the incident
    Then I should not see content "357"
    And I should see content "1000"
    And I should see content "Earth"

  @ignore
  Scenario: Add suggested source and abandon changes
    When I navigate to "/events"
    And I click the first item in the event list
    And I add the first suggested event document
    And I add the first suggested incident
    Then I can "abandon" suggestions

  @ignore
  Scenario: Add suggested source and confirm changes
    When I navigate to "/events"
    And I click the first item in the event list
    And I add the first suggested event document
    And I add the first suggested incident
    Then I can "confirm" suggestions

  Scenario: Extract incidents on extract incidents page
    When I navigate to "/extract-incidents"
    And I extract incidents from the url "http://www.promedmail.org/post/2579682"
    And I open the first incident
    And I set the count to "500"
    And I accept the incident
    Then the first incident should have a count of "500"
