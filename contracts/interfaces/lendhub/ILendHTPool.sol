// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ILendHTPool {
    function mint() external payable;
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function getAccountSnapshot(address account) external view returns ( uint256, uint256, uint256, uint256 );
}