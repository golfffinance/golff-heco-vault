// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IGOFController.sol";
import "./interfaces/IWHT.sol";

contract GOFVaultHT is ERC20, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    IERC20 public token;

    uint public min = 9990;
    uint public constant max = 10000;
    uint public earnLowerlimit;

    address public controller;

    constructor (address _token, address _controller, uint256 _earnLowerlimit) 
    public ERC20(
        string(abi.encodePacked("Golff ", ERC20(_token).name())),
        "G-HECOHT"
    ) {
        token = IERC20(_token);
        controller = _controller;
        earnLowerlimit = _earnLowerlimit;
        _setupDecimals(ERC20(_token).decimals());
    }

    function stakeToken() external view returns (address) {
        return address(token);
    }

    function balance() public view returns (uint) {
        return token.balanceOf(address(this))
                .add(IGOFController(controller).balanceOf(address(token)));
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

    function available() public view returns (uint) {
        return token.balanceOf(address(this)).mul(min).div(max);
    }

    function earn() public {
        uint _bal = available();
        token.safeTransfer(controller, _bal);
        IGOFController(controller).earn(address(token), _bal);
    }

    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }

    function deposit(uint _amount) public {
        uint _pool = balance();
        uint _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint _after = token.balanceOf(address(this));
        _amount = _after.sub(_before);
        uint shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
        if (token.balanceOf(address(this))>earnLowerlimit){
          earn();
        }
    }

    function depositHT() public payable {
        uint _pool = balance();
        uint _before = token.balanceOf(address(this));
        uint _amount = msg.value;
        IWHT(address(token)).deposit{value:_amount}();//.value(_amount)();
        uint _after = token.balanceOf(address(this));
        _amount = _after.sub(_before);
        uint shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
        if (token.balanceOf(address(this))>earnLowerlimit){
          earn();
        }
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function withdrawAllHT() external {
        withdrawHT(balanceOf(msg.sender));
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

    function withdrawHT(uint _shares) public{
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

        IWHT(address(token)).withdraw(r);
        address(uint160(msg.sender)).transfer(r);
    }

    function getPricePerFullShare() public view returns (uint) {
        return balance().mul(1e18).div(totalSupply());
    }
    
    receive() external payable {
        if (msg.sender != address(token)) {
            depositHT();
        }
    }
}