// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// This lottery uses a FLEXIBLE HYBRID system that triggers draws based on
/// either TIME or TICKET COUNT - whichever comes first (as long as minimums are met).
///
/// HOW IT WORKS:
///
/// Scenario 1: Normal Weekly Draw
/// - 7 days pass, 50 people bought 150 tickets
/// - Minimums met (5 people, 10 tickets)
/// - Draw triggers automatically at the 7-day mark
///
/// Scenario 2: Early Trigger
/// - Only 3 days have passed, but 500 tickets already sold!
/// - Hit the maxTicketsPerDraw limit
/// - Draw triggers early - don't make people wait!
///
/// Scenario 3: No Draw
/// - 7 days pass, but only 3 people bought 8 tickets
/// - Minimums NOT met (need 5 people, 10 tickets)
/// - Draw cannot start - tickets roll over to next period
///
/// WHY THIS SYSTEM?
/// - Predictable: Players know max wait time is configurable (default 7 days)
/// - Fair: Won't run tiny draws with too few people
/// - Dynamic: Hot weeks trigger early, slow weeks wait
///
/// All parameters are set in the constructor and can be adjusted by the host over time.

import "contract/Player.sol";
import "contract/ILottery.sol";
import "utils/Utils.sol";

/// Lottery with immutability.
contract Lottery is ILottery {
    // A dictionary of an address to the tickets it has purchased in the current iteration of the lottery.
    mapping(address => Player) public participantsToTickets;
    uint16 private totalTickets = 0;
    address[] participantAddresses;

    address payable public host;

    uint256 public prizePool = 0;
    uint256 private hostCut = 0;
    uint256 public ticketCost = 0.015 ether;
    uint256 private hostTicketFee = (ticketCost * 20) / 100; // Host takes a 20% cut from each ticket. the remaining 80% is for prize money

    // Randomness & Draw State
    uint256 public drawBlockNumber; // Block we'll use later for randomness
    bool public drawInitiated = false; // Stops someone from starting the draw twice
    bool public ended = false; // Prevents double payout
    uint256 public lastDrawTime = 0; // When the last draw happened (0 means never)

    mapping(address => uint256) public claimableWinnings; // Track how much each winner can claim

    // Trigger Parameters
    uint256 public drawInterval; // Maximum time between draws
    uint16 public minParticipants; // Minimum players needed to run a draw
    uint16 public minTicketsSold; // Minimum tickets needed to run a draw
    uint16 public maxTicketsPerDraw; // Draw triggers early if this many tickets sold

    constructor(
        uint256 _drawInterval,
        uint16 _minParticipants,
        uint16 _minTicketsSold,
        uint16 _maxTicketsPerDraw
    ) {
        // User who deployed the contract
        host = payable(msg.sender);

        require(_drawInterval >= 1 days, "Interval must be at least 1 day");
        require(_drawInterval <= 30 days, "Interval cannot exceed 30 days");
        drawInterval = _drawInterval;

        require(_minParticipants >= 2, "Need at least 2 participants");
        require(_minParticipants <= 100, "Too high - would never trigger");
        minParticipants = _minParticipants;

        require(
            _minTicketsSold >= _minParticipants,
            "Min tickets should be >= min participants"
        );
        require(_minTicketsSold <= 1000, "Too high - would never trigger");
        minTicketsSold = _minTicketsSold;

        require(
            _maxTicketsPerDraw >= _minTicketsSold,
            "Max must be >= min tickets"
        );
        require(_maxTicketsPerDraw <= 10000, "Too high - unrealistic cap");
        maxTicketsPerDraw = _maxTicketsPerDraw;
    }

    modifier onlyHost() {
        require(msg.sender == host, "You are not the host.");
        _;
    }

    // These allow the host to tune lottery parameters over time based on participation

    function setDrawInterval(uint256 _interval) external onlyHost {
        require(_interval >= 1 days, "Interval must be at least 1 day");
        require(_interval <= 30 days, "Interval cannot exceed 30 days");
        drawInterval = _interval;
    }

    function setMinParticipants(uint16 _minParticipants) external onlyHost {
        require(_minParticipants >= 2, "Need at least 2 participants");
        require(_minParticipants <= 100, "Too high - would never trigger");
        minParticipants = _minParticipants;
    }

    function setMinTicketsSold(uint16 _minTickets) external onlyHost {
        require(
            _minTickets >= minParticipants,
            "Min tickets should be >= min participants"
        );
        require(_minTickets <= 1000, "Too high - would never trigger");
        minTicketsSold = _minTickets;
    }

    function setMaxTicketsPerDraw(uint16 _maxTickets) external onlyHost {
        require(_maxTickets >= minTicketsSold, "Max must be >= min tickets");
        require(_maxTickets <= 10000, "Too high - unrealistic cap");
        maxTicketsPerDraw = _maxTickets;
    }

    /*
     *  buyTicket
     *  Allows a user to join the lottery by buying a ticket
     *  Adds them to lottery basket
     */
    function buyTicket(uint8[5] calldata ticketNumbers) external payable {
        require(!drawInitiated, "Cannot buy tickets during active draw");
        require(
            msg.value >= ticketCost,
            "Wrong amount of ether to join. Please pay at least 0.015 ether. Any more will be considered a tip."
        );
        validateTicketNumbers(ticketNumbers);

        // User Pays
        hostCut = hostTicketFee;
        prizePool += msg.value - hostCut;

        // Pay owner, using call gives us safety, transfer and send can fail, but this cancels everything
        (bool sent, ) = host.call{value: hostCut}("");
        require(sent, "Owner was not payed.");

        participantsToTickets[msg.sender].ticketNumbers.push(ticketNumbers);
        participantsToTickets[msg.sender].numberOfTickets += 1;

        if (!participantsToTickets[msg.sender].hasJoined) {
            participantsToTickets[msg.sender].hasJoined = true;

            participantAddresses.push(msg.sender);
        }

        totalTickets += 1;

        emit ParticipantJoined(msg.sender, "joined");
    }

    // Start the lottery draw
    function startLottery() external {
        // Make sure we aren't starting a second draw on the same round
        require(!drawInitiated, "Draw already initiated.");

        // Check minimum requirements are met (always required)
        require(
            participantAddresses.length >= minParticipants,
            "Not enough participants to start draw."
        );
        require(
            totalTickets >= minTicketsSold,
            "Not enough tickets sold to start draw."
        );

        // Check if either trigger condition is met:
        // 1. Time-based: drawInterval has passed, OR
        // 2. Ticket-based: maxTicketsPerDraw reached
        bool timeConditionMet = (lastDrawTime == 0) ||
            (block.timestamp >= lastDrawTime + drawInterval);
        bool ticketCapReached = totalTickets >= maxTicketsPerDraw;

        require(
            timeConditionMet || ticketCapReached,
            "Draw conditions not met. Wait for time interval or ticket cap."
        );

        // We use a block a few blocks in the future for randomness.
        // This helps because the block hasn't been mined yet,
        // so miners can't know or easily influence the final hash.
        drawBlockNumber = block.number + 5;

        // Mark that the draw officially started
        drawInitiated = true;

        // Record the timestamp for the time-limit system
        lastDrawTime = block.timestamp;
    }

    // Function to finalize the lottery and determine winners
    // Winners must call claimPrize() to withdraw their winnings
    function findWinner() external {
        // Can't finish something we didn't start
        require(drawInitiated, "Draw not initiated.");

        // Wait until the target block is reached
        require(
            block.number >= drawBlockNumber,
            "Target block hasn't arrived yet."
        );

        // Can't end twice
        require(!ended, "Lottery already ended.");

        // Get the blockhash for the block we planned earlier
        bytes32 futureBlockHash = blockhash(drawBlockNumber);

        // If blockhash returns zero, either the block is too old or not mined yet
        require(
            futureBlockHash != bytes32(0),
            "Block hash unavailable or too old."
        );

        // Generate 5 random winning numbers (1-99) using blockhash
        uint256 randomSeed = uint256(
            keccak256(abi.encodePacked(futureBlockHash, address(this)))
        );

        uint8[5] memory winningNumbers;
        for (uint256 i = 0; i < 5; i++) {
            winningNumbers[i] = uint8(
                (uint256(keccak256(abi.encodePacked(randomSeed, i))) % 99) + 1
            );
        }

        // Get all players
        uint256 numPlayers = participantAddresses.length;
        Player[] memory players = new Player[](numPlayers);
        for (uint256 i = 0; i < numPlayers; i++) {
            players[i] = participantsToTickets[participantAddresses[i]];
        }

        // Find winners who matched the numbers
        (address[] memory winners, uint256 amountPerWinner) = determinePrizes(
            prizePool,
            winningNumbers,
            participantAddresses,
            players
        );

        // SAFETY: Lock the lottery so no second payout happens
        ended = true;

        // Instead of transferring, mark winnings as claimable (for gas savings)
        if (winners.length > 0) {
            for (uint256 i = 0; i < winners.length; i++) {
                claimableWinnings[winners[i]] += amountPerWinner;
                emit LotteryWinner(winners[i], uint64(amountPerWinner));
            }
        }

        // Reset state for next round (but don't reset claimableWinnings, winners need to claim)
        prizePool = 0;
        totalTickets = 0;
        drawInitiated = false;
        ended = false;

        // Clear participant addresses
        for (uint256 i = 0; i < participantAddresses.length; i++) {
            delete participantsToTickets[participantAddresses[i]];
        }
        delete participantAddresses;
    }

    // Winners call this to claim their prize (pull payment pattern)
    function claimPrize() external {
        uint256 amount = claimableWinnings[msg.sender];
        require(amount > 0, "No winnings to claim");

        // Clear their winnings before transfer
        claimableWinnings[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Prize transfer failed");

        emit PrizeClaimed(msg.sender, amount);
    }

    /// Checks if a user is signed up for the lottery.
    /// Refactored from the original loop approach, which iterated over the entire participant array and would become inefficient as the number of participants grew.
    /// Now uses the `hasJoined` mapping, which provides a direct lookup for constant-time access regardless of how many people are in the lottery.
    /// @param user The address to check for participation.
    /// @return bool Returns true if the user has joined, false otherwise.
    function getParticipantStatus(address user) public view returns (bool) {
        return participantsToTickets[user].hasJoined;
    }

    // Check that all 5 numbers are unique and in range 1 -> 99
    function validateTicketNumbers(
        uint8[5] calldata ticketNumbers
    ) internal pure {
        for (uint256 i = 0; i < 5; i++) {
            require(
                ticketNumbers[i] >= 1 && ticketNumbers[i] <= 99,
                "Out of range"
            );
            for (uint256 j = i + 1; j < 5; j++) {
                require(
                    ticketNumbers[i] != ticketNumbers[j],
                    "Duplicate in ticket"
                );
            }
        }
    }

    /// Replaced the for loop in getParticipant with a direct mapping lookup. The old method got slower as more participants joined, so this keeps it fast regardless of size.
}
