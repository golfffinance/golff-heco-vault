// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IGOFController {
    
    function earn(address, uint) external;
    function balanceOf(address) external view returns (uint256 );
    function withdraw(address, uint) external;
    function getRewards() external view returns (address);
    function getVaults(address) external view returns (address);
}