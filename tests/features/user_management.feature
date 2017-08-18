@userManagement
Feature: User Management

  Background:
    Given I am logged in as an admin

  Scenario: Submit a blank user form
    Given I go to the account form
    And I submit a form that has email "" and name ""
    Then I should see an invalid form

  Scenario: Submit a valid user form
    Given I go to the account form
    And I submit a form that has email "test@test.com" and name "The Test"
    Then I should see a "success" notification
    And I should see content "The Test"
