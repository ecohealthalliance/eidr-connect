Feature: Admin

  Background:
    Given I am on the site
    And I am logged in as an admin

  @watch
  Scenario: Submit a blank user form
    Given I can go to the account form
    Then I cannot submit a blank account form

  @watch
  Scenario: Submit a valid user form
    Given I can go to the account form
    Then I can submit a form that has email "test@test.com" and name "The Test"
