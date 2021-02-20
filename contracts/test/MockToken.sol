// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockToken is ERC20, Ownable{
    /**
     * @notice Constructs the HERC-20 contract.
     */
    constructor(string memory name, uint8 decimals, uint256 initSupply) public ERC20('Golff Heco', name) {
        _setupDecimals(decimals);
        if(initSupply > 0) {
            _mint(msg.sender, initSupply);
        }
    }
    
    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        _mint(_to, _amount);
        return true;
    }
}