// SPDX-License-Identifier: MIT
// Testing file
pragma solidity ^0.8.18;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contract/Lottery.sol";

contract LotteryTesting {
    Lottery lottery;
    address participant1;
    address participant2;
    
    receive() external payable {}
    fallback() external payable {}

    // Run before every test function
    function beforeAll() public {
        participant1 = TestsAccounts.getAccount(1);
        participant2 = TestsAccounts.getAccount(2);
    }

    function beforeEach() public {
        // Draw interval, min prtcpts, max prtcpts, max ticket per
        lottery = new Lottery(2 days, 2, 2, 10);
    }
    
    // Check ownership
    function testHostIsOwner() public {
        Assert.equal(lottery.host(), address(this), "Owner is not set correctly.");
    }
    
    // Check ticket logic
    // Had to add this in wei, otherwise wouldn't work
    /// #value: 15000000000000000
    function testBuyIn() public payable {
        // Send value with the transaction
        Assert.equal(lottery.getParticipantStatus(address(this)), false, "A ticket was not bought/insufficient");
    }
    
    // Check the prize pool amount
    function testPrizePool() public {
        uint256 result = 1;
        lottery.buyTicket{value: 0.015 ether}([1, 2, 3, 4, 5]);
        Assert.equal(lottery.getParticipantStatus(address(this)), true, "A ticket was not bought/insufficient");
        Assert.ok(lottery.prizePool() > result, "Prize pool has no money.");
    }
    
    // Check to see if the pool was emptied
    function testClaimPrize() public {
        lottery.startLottery();
        Assert.equal(lottery.drawInitiated(), true, "The lottery has not started.");
        lottery.findWinner();
        lottery.claimPrize();
        Assert.ok(lottery.prizePool() < 1, "Prize pool was given away");
    }
    
    // Test start lottery
    function testStartLotteryPermission() public {
        Assert.equal(lottery.host(), address(this), "Only owner can start lottery");
    }
}