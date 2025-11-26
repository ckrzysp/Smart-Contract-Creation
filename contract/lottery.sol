// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/// Lottery with immutability.
contract Lottery {
    /// Essential variables for the lottery
    address[] participants;
    address public host;
    uint64 public constant monetaryPrize = 5 ether; 
    uint64 public ticketCost = 0.015 ether;
    event participantJoined(address prtcpt, string alert);
    event number(uint256 num);
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    uint256 public min;
    uint256 public max;

    constructor(uint256 min_, uint256 max_) {
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

    /*  FINISH
    *   findWinnerAndPay
    *   Generates random number to select from participants list and return winner
    */
    function findWinnerAndPay() public returns (hostPerm) {
        return host;
    }
}