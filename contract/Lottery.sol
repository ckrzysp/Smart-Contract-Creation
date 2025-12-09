/// REFACTOR SUGGESTION:
/// Right now the lottery is basically just an RNG that picks a random winner.
/// Players are not choosing numbers or interacting with anything that resembles
/// a real lottery.
///
/// We might want to shift toward a more traditional setup where users buy a
/// ticket, pick a set of numbers, and the payout depends on how many numbers
/// match the draw. This would make the system feel more like an actual lottery
/// and give players clearer expectations.
///
/// -------------------------------------------------------------------------------
///
/// Additional Features or SUGGESTIONS:
/// - Fixed draw intervals (daily, weekly) to create predictable and fair lottery rounds
/// - Dynamic ticket numbers: instead of fixed numbers, ticket numbers could evolve slightly
///   every block until purchase closes, adding unpredictability and strategic depth
/// - Tiered payouts / prizes: full match = jackpot, partial match = smaller rewards,
///   with optional bonus multipliers for rare combinations
/// - Participation limits: cap the number of tickets per draw and per player to prevent abuse
/// - Randomness improvements: enhancements beyond Chainlink VRF can address limitations
///   such as cost, speed, or decentralization, providing more flexible or efficient solutions
///
/// -------------------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "contract/Player.sol";
import "utils/Utils.sol";

/// Lottery with immutability.
contract Lottery is VRFV2PlusWrapperConsumerBase {
    // A dictionary of an address to the tickets it has purchased in the current iteration of the lottery.
    mapping(address => Player) public participantsToTickets = new mapping(address => Player);
    uint16 private totalTickets = 0;
    address[] participantAddresses = new address[];

    address payable public host;

    uint32 public ticketCost = 0.015 ether;
    uint32 hostTicketFee = ticketCost * 0.20; // Host takes a 20% cut from each ticket. the remaining 80% is for prize money

    event participantJoined(address prtcpt, string alert); // Event that alerts them when they join
    event lotterWinner(address winner, uint64 prize); // Event that alerts when there is a lottery winner

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    uint256 public requestId;

    constructor(
        uint256 min_,
        uint256 max_,
        address vrfWrapper
    ) VRFV2PlusWrapperConsumerBase(vrfWrapper) {
        // User who deployed the contract
        host = payable(msg.sender);
    }

    modifier onlyHost() {
        require(msg.sender == host, "You are not the host.");
        _;
    }

    // // Check that all 5 numbers are unique and in range 1 -> 99
    function validateTicketNumbers(uint8[5] calldata ticketNumbers) internal pure {
        for (uint256 i = 0; i < 5; i++) {
            require(ticketNumbers[i] >= 1 && ticketNumbers[i] <= 99, "Out of range");
            for (uint256 j = i + 1; j < 5; j++) {
                require(ticketNumbers[i] != ticketNumbers[j], "Duplicate in ticket");
            }
        }
    }

    /*
     *  joinLottery
     *  Allows a user to join the lottery by buying a ticket
     *  Adds them to lottery basket
     */
    function buyTicket(uint8[5] calldata ticketNumbers) external payable {
        require(
            msg.value < ticketCost, 
            "Wrong amount of ether to join. Please pay at least 0.15 ether. Any more will be considered a tip."
        );
        validateTicketNumbers(ticketNumbers);

        require(payable(msg.sender), "You have to be a payable address to be sent the lottery prize"); 

        participantsToTickets[msg.sender].push(ticketNumbers);
        participantsToTickets[msg.sender].numberOfTickets += 1;

        if (participantsToTickets[msg.sender].hasJoined = false) {
            participantsToTickets[msg.sender].hasJoined = true;

            participantAddresses.push(msg.sender);
        }

        totalTickets += 1;

        emit participantJoined(msg.sender, "joined");
    }

    function startLottery() external onlyHost {
        // require(participants.length > 0, "No participants");
        
        // Added this line to check to make sure the contract has enough money to pay the winner
        // Prevent lottery from starting without funds
        // require(address(this).balance >= monetaryPrize, "Insufficient contract balance for prize.");
        uint256 totalPrizePool = totalTickets * (ticketCost * 0.8);
        uint8[5] winningNumbers = [1, 2, 3, 4, 5];  // This is just an example
        uint256 numPlayers = participantAddresses.length;
        Player[] players = new Player[](numPlayers);

        for (uint256 i = 0; i < numPlayers; i++) {
            players.push(participantsToTickets[participantAddresses[i]]);
        }

        (address[] winners, uint256 amountWon) = determinePrizes(
            totalPrizePool,
            winningNumbers,
            participantAddresses,
            players
        );

        for (uint256 i = 0; i < winners.length; i++) {
            // Send the money to each address
        }
    
        // Request random number from Chainlink VRF v2.5 Direct Funding
        // bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
        //     VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
        // );
        // (requestId, ) = requestRandomness(100000, 3, 1, extraArgs);
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

    /// Checks if a user is signed up for the lottery.
    /// Refactored from the original loop approach, which iterated over the entire participant array and would become inefficient as the number of participants grew.
    /// Now uses the `hasJoined` mapping, which provides a direct lookup for constant-time access regardless of how many people are in the lottery.
    /// @param user The address to check for participation.
    /// @return bool Returns true if the user has joined, false otherwise.
    function getParticipantStatus(address user) public view returns (bool) {
        return participantsToTickets[user];
    }

    /// Replaced the for loop in getParticipant with a direct mapping lookup. The old method got slower as more participants joined, so this keeps it fast regardless of size.


}





