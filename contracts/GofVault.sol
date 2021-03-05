// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IGOFController.sol";

contract GOFVault is ERC20, Ownable{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    IERC20 public token;
    
    uint public min = 9500;
    uint public constant max = 10000;
    uint public earnLowerlimit;

    address public controller;
    
    constructor (
        address _token, 
        string memory _symbol, 
        address _controller, 
        uint _earnLowerlimit
    ) public ERC20(
        string(abi.encodePacked("Golff ", ERC20(_token).name())),
        string(abi.encodePacked("G-HECO", _symbol))
    ) {
        token = IERC20(_token);
        controller = _controller;
        earnLowerlimit = _earnLowerlimit;
        _setupDecimals(ERC20(_token).decimals());
    }

    function setMin(uint _min) external onlyOwner{
        min = _min;
    }

    function setController(address _controller) public onlyOwner{
        controller = _controller;
    }

    function setEarnLowerlimit(uint256 _earnLowerlimit) public onlyOwner{
        earnLowerlimit = _earnLowerlimit;
    }
    
    function balance() public view returns (uint) {
        return token.balanceOf(address(this))
                .add(IGOFController(controller).balanceOf(address(token)));
    }
    
    function available() public view returns (uint) {
        return token.balanceOf(address(this)).mul(min).div(max);
    }
    
    function deposit(uint _amount) public {
        uint _pool = balance();
        uint _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint _after = token.balanceOf(address(this));
        _amount = _after.sub(_before); // Additional check for deflationary tokens
        uint _shares = 0;
        if (totalSupply() == 0) {
            _shares = _amount;
        } else {
            _shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, _shares);
        if (token.balanceOf(address(this)) > earnLowerlimit){
            earn();
        }
    }

    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }
    
    function withdraw(uint _shares) public {
        uint r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);
        
        uint b = token.balanceOf(address(this));
        if (b < r) {
            uint _withdraw = r.sub(b);
            IGOFController(controller).withdraw(address(token), _withdraw);
            uint _after = token.balanceOf(address(this));
            uint _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }
        
        token.safeTransfer(msg.sender, r);
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function earn() public {
        uint bal = available();
        token.safeTransfer(controller, bal);
        IGOFController(controller).earn(address(token), bal);
    }
    
    function getPricePerFullShare() public view returns (uint) {
        return balance().mul(1e18).div(totalSupply());
    }
}