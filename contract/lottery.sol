// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// Lottery with immutability.
contract Lottery {
    /// Essential variables for the lottery
    address[] participants;
    address public host;
    uint64 public constant monetaryPrize = 5 ether; 
    uint64 public ticketCost = 0.015 ether;
    event participantJoined(address prtcpt, string alert);

    constructor() {
        // User who deployed the contract
        host = payable(msg.sender);
    }

    modifier hostPerm() {
        require(msg.sender == host, "You are not the host.");
        _;
    }

    /*
    *   joinLottery() 
    *   Allows a user to join the lottery by buying a ticket
    *   Adds them to lottery basket
    */
    function joinLottery() public payable {
        require(msg.value == ticketCost, "Wrong Amount.");
        participants.push(msg.sender);
    }

    /*
    *   getParticipant() 
    *   Get User in lottery
    */
    function getParticipant(address user) public view returns (address) { 
        address found = host;
        for(uint64 i = 0; i < participants.length; i++) {
            if(user == participants[i]) {
                found = participants[i];
                return found;
            }
        }
        return host;
    }

    function findWinnerAndPay() public returns (hostPerm) {
        return host;
    }
}