# Milestone Crowdfunding

A Solidity smart contract for funding a project in stages using ERC-20 tokens. Built with Foundry.

## What it does

A creator opens a campaign with a funding target, deadline, accepted token and a set of milestones. Contributors send tokens before the deadline. If the target is reached, the creator can withdraw funds milestone by milestone in order. If the target is not reached or the campaign is cancelled, all contributors can claim full refunds. No duplicate refunds are allowed.

## Setup

git clone https://github.com/Alike001/milestone-crowdfunding
cd milestone-crowdfunding
forge install
forge build

## Run Tests

forge test -vvv

## Contract Functions

- createCampaign() — creator opens a campaign with target, deadline, token and milestones
- contribute() — contributor sends tokens before the deadline
- releaseMilestone() — creator withdraws the next milestone amount after target is reached
- cancelCampaign() — creator cancels the campaign before the deadline
- refund() — contributor claims full refund if target failed or campaign was cancelled

## Key Rules

- Contributions only accepted before the deadline
- Milestones must sum exactly to the campaign target
- Milestones released in order — cannot skip
- Refunds available only when target fails or campaign is cancelled
- No duplicate refunds allowed
- Creator can only withdraw after deadline and target is reached

## Built with

- Solidity ^0.8.20
- Foundry
- Forge tests with vm.warp, vm.prank, vm.expectRevert
