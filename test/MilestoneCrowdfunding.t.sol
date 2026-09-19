// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MilestoneCrowdfunding.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount);
        require(allowance[from][msg.sender] >= amount);
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MilestoneCrowdfundingTest is Test {
    MilestoneCrowdfunding crowd;
    MockERC20 token;

    address creator     = makeAddr("creator");
    address contributor1 = makeAddr("contributor1");
    address contributor2 = makeAddr("contributor2");
    address stranger    = makeAddr("stranger");

    uint256 constant TARGET   = 1000;
    uint256 deadline;
    uint256 campaignId;

    uint256[] milestoneAmounts;

    function setUp() public {
        crowd = new MilestoneCrowdfunding();
        token = new MockERC20();

        token.mint(contributor1, 10000);
        token.mint(contributor2, 10000);

        deadline = block.timestamp + 7 days;

        milestoneAmounts = new uint256[](3);
        milestoneAmounts[0] = 300;
        milestoneAmounts[1] = 300;
        milestoneAmounts[2] = 400;

        vm.prank(creator);
        campaignId = crowd.createCampaign(
            address(token),
            TARGET,
            deadline,
            milestoneAmounts
        );

        vm.prank(contributor1);
        token.approve(address(crowd), 10000);

        vm.prank(contributor2);
        token.approve(address(crowd), 10000);
    }

    function test_contributeSuccessfully() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 500);

        assertEq(crowd.contributions(campaignId, contributor1), 500);
    }

    function test_rejectContributeAfterDeadline() public {
        vm.warp(deadline + 1);

        vm.prank(contributor1);
        vm.expectRevert(MilestoneCrowdfunding.DeadlinePassed.selector);
        crowd.contribute(campaignId, 500);
    }

    function test_targetReachedAfterFullFunding() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 600);

        vm.prank(contributor2);
        crowd.contribute(campaignId, 400);

        (, , , , , , , bool targetReached) = crowd.campaigns(campaignId);
        assertTrue(targetReached);
    }

    function test_releaseMilestoneInOrder() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 1000);

        vm.warp(deadline + 1);

        uint256 before = token.balanceOf(creator);

        vm.prank(creator);
        crowd.releaseMilestone(campaignId);

        assertEq(token.balanceOf(creator), before + 300);
    }

    function test_rejectReleaseMilestoneIfTargetNotReached() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 500);

        vm.warp(deadline + 1);

        vm.prank(creator);
        vm.expectRevert(MilestoneCrowdfunding.TargetNotReached.selector);
        crowd.releaseMilestone(campaignId);
    }

    function test_rejectUnauthorizedMilestoneRelease() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 1000);

        vm.warp(deadline + 1);

        vm.prank(stranger);
        vm.expectRevert(MilestoneCrowdfunding.NotCreator.selector);
        crowd.releaseMilestone(campaignId);
    }

    function test_refundWhenTargetFails() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 500);

        vm.warp(deadline + 1);

        uint256 before = token.balanceOf(contributor1);

        vm.prank(contributor1);
        crowd.refund(campaignId);

        assertEq(token.balanceOf(contributor1), before + 500);
    }

    function test_rejectDuplicateRefund() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 500);

        vm.warp(deadline + 1);

        vm.prank(contributor1);
        crowd.refund(campaignId);

        vm.prank(contributor1);
        vm.expectRevert(MilestoneCrowdfunding.AlreadyRefunded.selector);
        crowd.refund(campaignId);
    }

    function test_refundAfterCancellation() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 500);

        vm.prank(creator);
        crowd.cancelCampaign(campaignId);

        uint256 before = token.balanceOf(contributor1);

        vm.prank(contributor1);
        crowd.refund(campaignId);

        assertEq(token.balanceOf(contributor1), before + 500);
    }

    function test_allMilestonesReleasedInOrder() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 1000);

        vm.warp(deadline + 1);

        vm.startPrank(creator);
        crowd.releaseMilestone(campaignId);
        crowd.releaseMilestone(campaignId);
        crowd.releaseMilestone(campaignId);
        vm.stopPrank();

        assertEq(token.balanceOf(creator), 1000);
    }

    function test_rejectReleaseAfterAllMilestones() public {
        vm.prank(contributor1);
        crowd.contribute(campaignId, 1000);

        vm.warp(deadline + 1);

        vm.startPrank(creator);
        crowd.releaseMilestone(campaignId);
        crowd.releaseMilestone(campaignId);
        crowd.releaseMilestone(campaignId);

        vm.expectRevert(MilestoneCrowdfunding.AllMilestonesReleased.selector);
        crowd.releaseMilestone(campaignId);
        vm.stopPrank();
    }
}
