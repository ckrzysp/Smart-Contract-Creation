// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

struct Player {
    uint8[5][] ticketNumbers;
    bool hasJoined;
    uint16 numberOfTickets;
}