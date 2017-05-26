@eventMap
Feature: Event Map

  Background:
    Given I am logged in as an admin
    And I navigate to "/event-map"

  Scenario: View incidents on event map
    When I click the first event in the list
    When I click on a map marker
    Then I should see content "1 case in Ohio"
