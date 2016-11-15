Feature: Admin

  Background:
    Given I am on the site
    And I am logged in as an admin

  Scenario: Submit a blank user form
    Given I can go to the account form
    Then I cannot submit a blank account form

  Scenario: Submit a valid user form
    Given I can go to the account form
    Then I can submit a form that has email "test@test.com" and name "The Test"

  Scenario: Submit a blank event form
    Given I can go to the event list
    And I can click on the create new event button
    Then I cannot create an event with name "" and summary ""

  Scenario: Submit an event with only a name
    Given I can go to the event list
    And I can click on the create new event button
    Then I can create an event with name "A test" and summary ""

  Scenario: Submit an event form with only a summary
    Given I can go to the event list
    And I can click on the create new event button
    Then I cannot create an event with name "" and summary "A summary"

  Scenario: Submit an event with a name and summary
    Given I can go to the event list
    And I can click on the create new event button
    Then I can create an event with name "A test" and summary "A summary"

  Scenario: Delete an existing event
    Given I can go to the event list
    Then I can delete the first item in the event list

  Scenario: Cancel deleting an existing event
    Given I can go to the event list
    Then I cannot delete the first item in the event list
