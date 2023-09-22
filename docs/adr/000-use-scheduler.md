# Use EventBridge Scheduler to Trigger Scheduled Fargate Tasks

* Status: accepted
* Deciders: Cloud Guild
  * // TODO
* Date: 2023-09-22

## Context and Problem Statement

We used CloudWatch Event Rules and Targets to trigger scheduled Fargate tasks.
AWS has a newer service called [EventBridge Scheduler](https://docs.aws.amazon.com/eventbridge/latest/userguide/scheduler.html).
Do we start using the Scheduler to take advantage of those newer features?

## Decision Drivers <!-- optional -->

* Would be nice if our tasks could support time zone scheduled jobs
* Needs to be easy to use

## Considered Options

* Keep using Event Rules and Targets
* Use EventBridge Scheduler (keep event trigger functionality)
* Use EventBridge Scheduler (move event trigger functionality to new module)
* Use EventBridge Scheduler and refactor fargate modules

## Decision Outcome

Chosen option: "Use EventBridge Scheduler (move event trigger functionality to new module)", because triggering a Fargate task off of an event doesn't quite fit with the name of this module "terraform-aws-scheduled-fargate."

## Pros and Cons of the Options <!-- optional -->

### Keep using Event Rules and Targets

* Good, because there'll be no change to our module
* Good, because it still works
* Bad, because we can't take advantage of the EventBridge Scheduler features (time zone, start-end dates, retries etc.)

### Use EventBridge Scheduler (keep event trigger functionality)

* Good, because we can take advantage of the EventBridge Scheduler features (time zone, start-end dates, retries etc.)
* Good, because we can still support tasks triggered by tasks
* Bad, because the module will be more complex (it will include resources for both EventBridge Scheduler, and CloudWatch Rules and Targets)

### Use EventBridge Scheduler (move event trigger functionality to new module)

* Good, because we can take advantage of the EventBridge Scheduler features (time zone, start-end dates, retries etc.)
* Good, because this module will be simplified
* Bad, because in order to support tasks triggered by tasks we'll need to create a new module (with lots of copy/paste terraform configuration)

### Use EventBridge Scheduler and refactor fargate modules

We can refactor the fargate-api, and scheduled-fargate modules into smaller pieces that work together in order to reduce duplicate terraform code.
Maybe something like:
* `fargate-definition` module that sets up the fargate task definition, ECS cluster, SGs, related IAM roles etc.
* `fargate-service` module that takes task definition and cluster inputs from 'fargate-defintion' module, and creates an ECS service with ALB, CodeDeploy, related IAM roles etc.
* `fargate-scheduled` module that takes task definition and cluster inputs from 'fargate-defintion' module, and creates Scheduler that runs the task on the schedule, related IAM roles etc.
* `fargate-event` module that takes task definition and cluster inputs from 'fargate-defintion' module, and creates CloudWatch Event to trigger task, Rule(s), Target(s), and related IAM roles etc.

* Good, because we can reduce duplicate terraform
* Good, because our modules can be smaller and simpler, thus easier to maintain
* Bad, because it completely breaks our exising terraform module contract, so upgrades will be more difficult
* Bad, because it makes our apps a little more complex having to use interconnected modules instead of just one. It borders on not needing modules in the first place if our apps have to know how everything integrates.

## Links <!-- optional -->

* [EventBridge Scheduler](https://docs.aws.amazon.com/eventbridge/latest/userguide/scheduler.html)
