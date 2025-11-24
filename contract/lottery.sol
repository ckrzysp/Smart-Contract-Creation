// SPDX-License-Identifier: MIT
// @custom:dev-run-script ./contract/lottery.sol
pragma solidity ^0.8.0;
import "hardhat/console.sol";

/// Lottery with immutability.
contract Lottery {
    /// Essential variables for the lottery
    address[] participants;
    address public host;
    int64 public constant monetaryPrize = 5 * 10**5; 
    int64 public ticketCost = 0.015 ether;

    constructor() {
        // User who deployed the contract
        host = msg.sender;
    }

    /* Add functions
    * entry purchase
    * winner selection
    * money transfer 
    * - Christopher / Krzysio
    */ 
}