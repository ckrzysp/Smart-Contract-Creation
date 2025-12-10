// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "contract/Player.sol";

function determinePrizes(
    uint256 totalPrizePool,
    uint8[5] memory winningNumbers,
    address[] memory addresses,
    Player[] memory players
) pure returns (address[] memory winners, uint256 winAmount) {
    require(addresses.length == players.length, "Length mismatch");

    uint256 totalJackpotWinners = 0;

    // find all jackpot winners
    for (uint256 i = 0; i < players.length; i++) {  // for each player
        uint256 n = players[i].numberOfTickets;

        for (uint256 j = 0; j < n; j++) {  // for each ticket the current player has
            uint8[5] memory ticket = players[i].ticketNumbers[j];

            bool isJackpotWinner = true;
            for (uint8 x = 0; x < 5; x++) {
                if (ticket[x] != winningNumbers[x]) {
                    isJackpotWinner = false;
                    break;
                }
            }

            if (isJackpotWinner) {
                totalJackpotWinners += 1;
            }
        }
    }

    if (totalJackpotWinners == 0) {
        return (new address[](0), 0);
    }
    
    // Allocate winners with a fixed size
    winners = new address[](totalJackpotWinners);
    uint256 winnerIndex = 0;
    uint256 share = totalPrizePool / totalJackpotWinners;

    // Populate winners
    for (uint256 i = 0; i < players.length; i++) {
        uint256 n = players[i].numberOfTickets;

        for (uint256 j = 0; j < n; j++) {
            bool isJackpotWinner = true;

            for (uint256 x = 0; x < 5; x++) {
                if (players[i].ticketNumbers[x][j] != winningNumbers[x]) {
                    isJackpotWinner = false;
                    break;
                }
            }

            if (isJackpotWinner) {
                winners[winnerIndex] = addresses[i];
                winnerIndex++;
            }
        }
    }

    return (winners, share);
}