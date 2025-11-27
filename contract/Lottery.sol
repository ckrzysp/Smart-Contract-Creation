// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// Lottery with immutability.
contract Lottery is VRFV2PlusWrapperConsumerBase {
    /// Essential variables for the lottery
    address[] participants;
    mapping(address => bool) public hasJoined; // Prevent same person joining twice
    address payable public host;
    uint64 public constant monetaryPrize = 5 ether;
    uint256 amountToSend = monetaryPrize;
    uint64 public ticketCost = 0.015 ether;
    event participantJoined(address prtcpt, string alert); // Event that alerts them when they join
    event lotterWinner(address winner, uint64 prize); // Event that alerts when there is a lottery winner
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    uint256 public requestId;
    uint256 public min;
    uint256 public max;
    bool public ended = false;

    constructor(
        uint256 min_,
        uint256 max_,
        address vrfWrapper
    ) VRFV2PlusWrapperConsumerBase(vrfWrapper) {
        // User who deployed the contract
        host = payable(msg.sender);
        min = min_;
        max = max_;
    }

    modifier onlyHost() {
        require(msg.sender == host, "You are not the host.");
        _;
    }

    /*
     *  joinLottery
     *  Allows a user to join the lottery by buying a ticket
     *  Adds them to lottery basket
     */
    function joinLottery() external payable {
        require(!ended, "Lottery has ended.");
        require(msg.value == ticketCost, "Wrong Amount.");
        require(participants.length < max, "This lottery is full.");
        require(
            !hasJoined[msg.sender],
            "You have already joined this lottery."
        );

        participants.push(msg.sender);
        hasJoined[msg.sender] = true;
        emit participantJoined(msg.sender, "joined");
    }

    /*  
     *  findWinner
     *  Only host can start the lottery, random number from VRF
     *  Returns void, calculates random number
     */

    /*
    function start() external onlyHost {
        require(!ended, "Lottery has already ended");
        require(
            participants.length >= min,
            "There are not enough people to start this lottery"
        );
        require(participants.length > 0, "No participants");
    
        // Request random number from Chainlink VRF v2.5 Direct Funding
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
        );
        (requestId, ) = requestRandomness(100000, 3, 1, extraArgs);
    }
    */

    function start() external onlyHost {
        require(!ended, "Lottery has already ended");
        require(
            participants.length >= min,
            "There are not enough people to start this lottery"
        );
        require(participants.length > 0, "No participants");
        
        // Added this line to check to make sure the contract has enough money to pay the winner
        // Prevent lottery from starting without funds
        require(address(this).balance >= monetaryPrize, "Insufficient contract balance for prize.");
    
        // Request random number from Chainlink VRF v2.5 Direct Funding
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
        );
        (requestId, ) = requestRandomness(100000, 3, 1, extraArgs);
    }

    /*  
     *  findWinner
     *  Generates random number to select from participants list and return winner
     *  Returns winner
     */
    function findWinner() private view returns (address) {
        // Get random participant using chainlink VRFConsumerBase
        // For reference, we should implement direct funding VRF paid by the lottery fee instead
        // of subscription funding since we're looking to get a random number once per contract.
        // Docs: https://docs.chain.link/vrf/v2-5/overview/direct-funding

        // Use random number from Chainlink to select winner
        uint256 winnerIndex = randomResult % participants.length;
        return participants[winnerIndex];
    }

    /*
     *  fulfillRandomWords
     *  Chainlink VRF calls this function with the random number (callback)
     *  Returns void, transfers money
    */ 
    function fulfillRandomWords(
        uint256 _requestId, 
        uint256[] memory _randomWords
    ) internal override {
        require(_randomWords.length > 0, "No random words received.");
        require(participants.length > 0, "No participants.");

        randomResult = _randomWords[0];
        address winnerAddress = findWinner();

        emit lotterWinner(winnerAddress, monetaryPrize);
        ended = true;
        
        // Pay winner
        require(msg.value >= amountToSend, "Failed to send prize amount.");
        payable(winnerAddress).transfer(amountToSend);
        amountToSend = 0;
    }

    /*
     *   getParticipant
     *   Get User in lottery
     *   Returns participant
     */

    /*
    function getParticipant(address user) private view returns (address) {
        address found = host;

        for (uint64 i = 0; i < participants.length; i++) {
            if (user == participants[i]) {
                found = participants[i];
                return found;
            }
        }

        return found;
    }
    */

    /// Checks if a user is signed up for the lottery.
    /// Refactored from the original loop approach, which iterated over the entire participant array and would become inefficient as the number of participants grew.
    /// Now uses the `hasJoined` mapping, which provides a direct lookup for constant-time access regardless of how many people are in the lottery.
    /// @param user The address to check for participation.
    /// @return bool Returns true if the user has joined, false otherwise.
    function getParticipantStatus(address user) public view returns (bool) {
        return hasJoined[user];
    }

    /// Replaced the for loop in getParticipant with a direct mapping lookup. The old method got slower as more participants joined, so this keeps it fast regardless of size.


}



