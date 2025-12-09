// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "contract/Player.sol";

interface ILottery {
    /// @notice Emitted when a participant joins the lottery
    /// @param prtcpt The address of the participant
    /// @param alert Alert message
    event participantJoined(address prtcpt, string alert);

    /// @notice Emitted when a winner is selected
    /// @param winner The address of the winner
    /// @param prize The prize amount won
    event lotterWinner(address winner, uint64 prize);

    /// @notice Update the draw interval (time between draws)
    /// @param _interval New interval in seconds (must be between 1-30 days)
    function setDrawInterval(uint256 _interval) external;

    /// @notice Update the minimum number of participants required
    /// @param _minParticipants New minimum (must be between 2-100)
    function setMinParticipants(uint16 _minParticipants) external;

    /// @notice Update the minimum number of tickets required
    /// @param _minTickets New minimum (must be >= minParticipants)
    function setMinTicketsSold(uint16 _minTickets) external;

    /// @notice Update the maximum tickets per draw (triggers early draw)
    /// @param _maxTickets New maximum (must be >= minTicketsSold)
    function setMaxTicketsPerDraw(uint16 _maxTickets) external;

    /// @notice Buy a lottery ticket with chosen numbers
    /// @param ticketNumbers Array of 5 unique numbers (1-99)
    function buyTicket(uint8[5] calldata ticketNumbers) external payable;

    /// @notice Start the lottery draw process
    /// @dev Can only be called when minimum requirements are met and trigger conditions satisfied
    function startLottery() external;

    /// @notice Finalize the lottery and select a winner
    /// @dev Must be called after startLottery() and after the target block is reached
    function findWinner() external;

    /// @notice Check if a user has joined the current lottery
    /// @param user The address to check
    /// @return True if the user has joined, false otherwise
    function getParticipantStatus(address user) external view returns (bool);

    /// @notice Get participant's ticket information
    /// @param user The address to query
    /// @return Player struct containing ticket data
    function participantsToTickets(
        address user
    ) external view returns (Player memory);

    /// @notice Get the contract host address
    /// @return The host's address
    function host() external view returns (address payable);

    /// @notice Get the current prize pool
    /// @return The prize pool amount
    function prizePool() external view returns (uint32);

    /// @notice Get the ticket cost
    /// @return The cost per ticket
    function ticketCost() external view returns (uint32);

    /// @notice Get the block number for randomness
    /// @return The target block number
    function drawBlockNumber() external view returns (uint256);

    /// @notice Check if a draw has been initiated
    /// @return True if draw is in progress
    function drawInitiated() external view returns (bool);

    /// @notice Get the timestamp of the last draw
    /// @return Unix timestamp
    function lastDrawTime() external view returns (uint256);

    /// @notice Get the draw interval
    /// @return Time in seconds between draws
    function drawInterval() external view returns (uint256);

    /// @notice Get minimum participants required
    /// @return Minimum number of participants
    function minParticipants() external view returns (uint16);

    /// @notice Get minimum tickets required
    /// @return Minimum number of tickets
    function minTicketsSold() external view returns (uint16);

    /// @notice Get maximum tickets per draw
    /// @return Maximum tickets before early trigger
    function maxTicketsPerDraw() external view returns (uint16);
}
