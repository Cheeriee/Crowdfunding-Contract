// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Launch.sol";

contract LaunchTest is Test {
    Launch launch;
    address owner = address(0x1);
    address contributor1 = address(0x2);
    address nonOwner = address(0x3);
    uint256 goal = 10 ether;
    uint256 duration = 1 days;

    event Contributed(address indexed contributor, uint256 indexed amount);
    event CampaignStatus(uint256 totalContributed, bool goalReached, bool deadlinePassed);
    event Withdrawn(address indexed owner, uint256 indexed amount);
    event ContributorRefunded(address indexed contributor, uint256 indexed amount);



    function setUp() public {
        vm.prank(owner);
        launch = new Launch(duration, goal);
    }

    // Test constructor initialization and invalid inputs
    function testConstructor() public {
        assertEq(launch.owner(), owner, "Owner should be set");
        assertEq(launch.goal(), goal, "Goal should be set");
        assertEq(launch.deadline(), block.timestamp + duration, "Deadline should be set");
        assertEq(launch.totalContributed(), 0, "Total contributed should be 0");
        assertFalse(launch.goalReached(), "Goal reached should be false");

        vm.expectRevert(Launch.InvalidGoal.selector);
        new Launch(duration, 0);
        vm.expectRevert(Launch.InvalidDeadline.selector);
        new Launch(0, goal);
    }

    // Test valid contribution
    function testContribute() public {
        vm.prank(contributor1);
        vm.deal(contributor1, 1 ether);
        vm.expectEmit(true, true, false, true);
        emit Contributed(contributor1, 1 ether);
        vm.expectEmit(false, false, false, true);
        emit CampaignStatus(1 ether, false, false);
        launch.contribute{value: 1 ether}();
        (uint256 amount, bool hasWithdrawn) = launch.getContribution(contributor1);
        assertEq(amount, 1 ether, "Contribution amount should be 1 ether");
        assertFalse(hasWithdrawn, "Contributor should not have withdrawn");
        assertEq(launch.totalContributed(), 1 ether, "Total contributed should be 1 ether");
    }

    // Test contribution with zero value
    function testContributeInsufficientAmount() public {
        vm.prank(contributor1);
        vm.expectRevert(Launch.InsufficientAmount.selector);
        launch.contribute{value: 0}();
    }

    
    // Test contribution after deadline
    function testContributeCampaignEnded() public {
        vm.warp(block.timestamp + duration + 1);
        vm.prank(contributor1);
        vm.deal(contributor1, 1 ether);
        vm.expectRevert(Launch.CampaignEnded.selector);
        launch.contribute{value: 1 ether}();
    }

    function testwithdrawOwner() public {
        vm.prank(contributor1);
        vm.deal(contributor1, goal);
        launch.contribute{value: goal}();

    }

    // Test owner withdrawal after goal met
    function testWithdrawOwner() public {
        vm.prank(contributor1);
        vm.deal(contributor1, goal);
        launch.contribute{value: goal}();
        vm.warp(block.timestamp + duration + 1);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(owner, goal);
        launch.withdrawOwner();
        assertTrue(launch.ownerWithdrawn(), "Owner should have withdrawn");
        assertEq(address(launch).balance, 0, "Contract balance should be 0");
    }

     // Test non-owner cannot withdraw
    function testWithdrawOwnerNotOwner() public {
        vm.prank(contributor1);
        vm.deal(contributor1, goal);
        launch.contribute{value: goal}();
        vm.warp(block.timestamp + duration + 1);
        vm.prank(nonOwner);
        vm.expectRevert(Launch.NotOwner.selector);
        launch.withdrawOwner();
    }

    // Test contributor refund when goal not met
    function testWithdrawContributor() public {
        vm.prank(contributor1);
        vm.deal(contributor1, 1 ether);
        launch.contribute{value: 1 ether}();
        vm.warp(block.timestamp + duration + 1);
        vm.prank(contributor1);
        vm.expectEmit(true, true, false, true);
        emit ContributorRefunded(contributor1, 1 ether);
        launch.withdrawContributor();
        (uint256 amount, bool hasWithdrawn) = launch.getContribution(contributor1);
        assertTrue(hasWithdrawn, "Contributor should have withdrawn");
        assertEq(address(launch).balance, 0, "Contract balance should be 0");
    }

    // Test refund attempt with no contribution
    function testWithdrawContributorNoContribution() public {
        vm.warp(block.timestamp + duration + 1);
        vm.prank(contributor1);
        vm.expectRevert(Launch.NoContribution.selector);
        launch.withdrawContributor();
    }

    // Test campaign status retrieval
    function testGetCampaignStatus() public {
        vm.prank(contributor1);
        vm.deal(contributor1, 1 ether);
        launch.contribute{value: 1 ether}();
        (uint256 currentFunds, uint256 goalAmount, uint256 deadlineTimestamp, bool isGoalReached, bool isDeadlinePassed, bool hasOwnerWithdrawn) = launch.getCampaignStatus();
        assertEq(currentFunds, 1 ether, "Current funds should be 1 ether");
        assertEq(goalAmount, goal, "Goal amount should match");
        assertEq(deadlineTimestamp, block.timestamp + duration, "Deadline should match");
        assertFalse(isGoalReached, "Goal should not be reached");
        assertFalse(isDeadlinePassed, "Deadline should not be passed");
        assertFalse(hasOwnerWithdrawn, "Owner should not have withdrawn");
    }

    // Test direct ETH transfer via receive
    function testReceiveEth() public {
        vm.prank(contributor1);
        vm.deal(contributor1, 1 ether);
        (bool success,) = address(launch).call{value: 1 ether}("");
        assertTrue(success, "Direct ETH transfer should succeed");
        assertEq(address(launch).balance, 1 ether, "Contract balance should be 1 ether");
        assertEq(launch.totalContributed(), 0, "Total contributed should remain 0");
        (uint256 amount,) = launch.getContribution(contributor1);
        assertEq(amount, 0, "Contributor amount should be 0");
    }
}



