// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IUnitroller {
    function claimComp(address holder) external;
    function claimComp(address holder, address[] calldata cTokens) external;
}