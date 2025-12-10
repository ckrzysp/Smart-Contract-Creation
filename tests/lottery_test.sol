// SPDX-License-Identifier: MIT
// Testing file
pragma solidity ^0.8.18;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contract/Lottery.sol";

contract LotteryTesting {
    Lottery lottery;
    address payable owner;
    address participant;

    // Being a new lottery
    function beforeEach() public {
        owner = payable(TestsAccounts.getAccount(0)); // Set owner
        participant = TestsAccounts.getAccount(1);
        lottery = new Lottery(20, 2, 2, 2);
    }

    // Check ownership
    function testHostIsOwner() public {
        Assert.equal(lottery.host(), owner, "Owner is not set correctly.");
    }

    // Check ticket logic
    function testBuyIn() public {
        lottery.buyTicket{value: 0.015 ether}([3, 42, 90, 81, 49]);
        Assert.equal(lottery.getParticipantStatus(participant), true, "A ticket was not bought/insufficient funds.");
    }

    // Check the prize pool amount
    function testPrizePool() public {
        uint256 result = 1;
        Assert.ok(lottery.prizePool() > result, "Prize pool has no money.");
    }

    // Check to see if the draw has started
    function testStartLottery() public {
        lottery.startLottery();
        Assert.equal(lottery.drawInitiated(), true, "The lottery has not started.");
    }

    // Check to see if the the pool was emptied 
    function testWinning() public {
        lottery.findWinner();
        Assert.ok(lottery.prizePool() < 1, "Prize pool was not given away");
    }
}