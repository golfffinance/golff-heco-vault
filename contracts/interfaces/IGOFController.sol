// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IGOFController {
    function withdraw(address, uint) external;
    function earn(address, uint) external;
    function balanceOf(address) external view returns (uint256 );
    function rewards() external view returns (address);
    function vaults(address) external view returns (address);
}