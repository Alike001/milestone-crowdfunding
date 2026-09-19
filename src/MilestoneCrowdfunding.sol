// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

library CampaignLib {
    function sum(uint256[] memory amounts) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
    }
}

contract MilestoneCrowdfunding {
    using CampaignLib for uint256[];

    struct Campaign {
        address creator;
        address token;
        uint256 target;
        uint256 deadline;
        uint256 totalRaised;
        uint256 nextMilestone;
        bool cancelled;
        bool targetReached;
    }

    struct Milestone {
        uint256 amount;
        bool released;
    }

    uint256 public campaignCount;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Milestone[]) public milestones;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public refunded;

    event CampaignCreated(uint256 indexed id, address indexed creator, address token, uint256 target, uint256 deadline);
    event Contributed(uint256 indexed id, address indexed contributor, uint256 amount);
    event MilestoneReleased(uint256 indexed id, uint256 milestoneIndex, uint256 amount);
    event RefundIssued(uint256 indexed id, address indexed contributor, uint256 amount);
    event CampaignCancelled(uint256 indexed id);

    error ZeroAmount();
    error ZeroAddress();
    error InvalidDeadline();
    error NoMilestones();
    error MilestonesMismatch();
    error DeadlinePassed();
    error DeadlineNotPassed();
    error TargetNotReached();
    error AllMilestonesReleased();
    error NotCreator();
    error AlreadyCancelled();
    error NotRefundable();
    error AlreadyRefunded();
    error NothingToRefund();
    error TransferFailed();

    function createCampaign(
        address token,
        uint256 target,
        uint256 deadline,
        uint256[] calldata milestoneAmounts
    ) external returns (uint256 id) {
        if (token == address(0)) revert ZeroAddress();
        if (target == 0) revert ZeroAmount();
        if (deadline <= block.timestamp) revert InvalidDeadline();
        if (milestoneAmounts.length == 0) revert NoMilestones();
        if (milestoneAmounts.sum() != target) revert MilestonesMismatch();

        campaignCount++;
        id = campaignCount;

        campaigns[id] = Campaign({
            creator: msg.sender,
            token: token,
            target: target,
            deadline: deadline,
            totalRaised: 0,
            nextMilestone: 0,
            cancelled: false,
            targetReached: false
        });

        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            milestones[id].push(Milestone({
                amount: milestoneAmounts[i],
                released: false
            }));
        }

        emit CampaignCreated(id, msg.sender, token, target, deadline);
    }

    function contribute(uint256 id, uint256 amount) external {
        Campaign storage c = campaigns[id];

        if (block.timestamp > c.deadline) revert DeadlinePassed();
        if (c.cancelled) revert AlreadyCancelled();
        if (amount == 0) revert ZeroAmount();

        bool ok = IERC20(c.token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        contributions[id][msg.sender] += amount;
        c.totalRaised += amount;

        if (c.totalRaised >= c.target) {
            c.targetReached = true;
        }

        emit Contributed(id, msg.sender, amount);
    }

    function releaseMilestone(uint256 id) external {
        Campaign storage c = campaigns[id];

        if (msg.sender != c.creator) revert NotCreator();
        if (block.timestamp <= c.deadline) revert DeadlineNotPassed();
        if (!c.targetReached) revert TargetNotReached();
        if (c.nextMilestone >= milestones[id].length) revert AllMilestonesReleased();

        uint256 index = c.nextMilestone;
        Milestone storage m = milestones[id][index];

        m.released = true;
        c.nextMilestone++;

        bool ok = IERC20(c.token).transfer(c.creator, m.amount);
        if (!ok) revert TransferFailed();

        emit MilestoneReleased(id, index, m.amount);
    }

    function cancelCampaign(uint256 id) external {
        Campaign storage c = campaigns[id];

        if (msg.sender != c.creator) revert NotCreator();
        if (c.cancelled) revert AlreadyCancelled();
        if (block.timestamp > c.deadline) revert DeadlinePassed();

        c.cancelled = true;

        emit CampaignCancelled(id);
    }

    function refund(uint256 id) external {
        Campaign storage c = campaigns[id];

        bool targetFailed = block.timestamp > c.deadline && !c.targetReached;
        bool isCancelled = c.cancelled;

        if (!targetFailed && !isCancelled) revert NotRefundable();
        if (refunded[id][msg.sender]) revert AlreadyRefunded();

        uint256 amount = contributions[id][msg.sender];
        if (amount == 0) revert NothingToRefund();

        refunded[id][msg.sender] = true;
        contributions[id][msg.sender] = 0;

        bool ok = IERC20(c.token).transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit RefundIssued(id, msg.sender, amount);
    }

    function getMilestones(uint256 id) external view returns (Milestone[] memory) {
        return milestones[id];
    }
}
