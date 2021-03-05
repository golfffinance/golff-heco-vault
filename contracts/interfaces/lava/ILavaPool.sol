// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ILavaPool {

    function balanceOf(address account) external view returns (uint256);
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function exit() external;
    function getReward() external;
    function earned(address account) external view returns (uint256);
    
}