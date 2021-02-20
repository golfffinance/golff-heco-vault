// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";

import  "../interfaces/IGOFStrategy.sol";
import  "../interfaces/mdex/IMdexRouter.sol";

interface Converter {
    function convert(address) external returns (uint);
}

contract GOFControllerV1 is Ownable{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    address public strategist;
    address public onesplit;

    address public rewards;
    address public factory;
    mapping(address => address) public vaults;
    mapping(address => address) public strategies;
    mapping(address => mapping(address => address)) public converters;
    
    mapping(address => mapping(address => bool)) public approvedStrategies;

    uint public split = 500;
    uint public constant max = 10000;
    address constant public wht = address(0x8543A3E99174913cEeaF8b10e890bC99c4a89420);

    constructor(address _rewards) public {
        strategist = tx.origin;
        onesplit = address(0xbb87D38beEecac5eB602791703763722e3E9F359);
        rewards = _rewards;
    }
    
    modifier checkStrategist(){
        require(msg.sender == strategist || msg.sender == owner(), "Golff:!strategist");
        _;
    }

    function setFactory(address _factory) public onlyOwner{
        factory = _factory;
    }
    
    function setSplit(uint _split) public onlyOwner{
        split = _split;
    }
    
    function setOneSplit(address _onesplit) public onlyOwner{
        onesplit = _onesplit;
    }
    
    function setRewards(address _rewards) public onlyOwner{
        rewards = _rewards;
    }
    
    function approveStrategy(address _token, address _strategy) public onlyOwner{
        approvedStrategies[_token][_strategy] = true;
    }

    function revokeStrategy(address _token, address _strategy) public onlyOwner{
        approvedStrategies[_token][_strategy] = false;
    }

    function setVault(address _token, address _vault) public checkStrategist{
        require(vaults[_token] == address(0), "Golff:vault exist");
        vaults[_token] = _vault;
    }

    function setConverter(address _input, address _output, address _converter) public checkStrategist{
        converters[_input][_output] = _converter;
    }
    
    function setStrategy(address _token, address _strategy) public checkStrategist{
        require(approvedStrategies[_token][_strategy] == true, "Golff:!approved");
        address _current = strategies[_token];
        if (_current != address(0)) {
           IGOFStrategy(_current).withdrawAll();
        }
        strategies[_token] = _strategy;
    }
    
    function earn(address _token, uint _amount) public {
        address _strategy = strategies[_token]; 
        address _want = IGOFStrategy(_strategy).want();
        if (_want != _token) {
            address converter = converters[_token][_want];
            IERC20(_token).safeTransfer(converter, _amount);
            _amount = Converter(converter).convert(_strategy);
            IERC20(_want).safeTransfer(_strategy, _amount);
        } else {
            IERC20(_token).safeTransfer(_strategy, _amount);
        }
        IGOFStrategy(_strategy).deposit();
    }
    
    function balanceOf(address _token) external view returns (uint) {
        return IGOFStrategy(strategies[_token]).balanceOf();
    }
    
    function withdrawAll(address _token) public checkStrategist{
        IGOFStrategy(strategies[_token]).withdrawAll();
    }
    
    function inCaseTokensGetStuck(address _token, uint _amount) public checkStrategist{
        IERC20(_token).safeTransfer(owner(), _amount);
    }
    
    function getExpectedReturn(address _strategy, address _token) public view returns (uint expected) {
        uint _balance = IERC20(_token).balanceOf(_strategy);
        address _want = IGOFStrategy(_strategy).want();
        // cal out amount
        address[] memory swap2TokenRouting;
        swap2TokenRouting[1] = wht;
        swap2TokenRouting[2] = _want;
        uint256[] memory amountsOut = IMdexRouter(onesplit).getAmountsOut(_balance, swap2TokenRouting);
        expected = amountsOut[swap2TokenRouting.length -1];
    }
    
    // Only allows to withdraw non-core strategy tokens ~ this is over and above normal yield
    function yearn(address _strategy, address _token) public checkStrategist{
        // This contract should never have value in it, but just incase since this is a public call
        uint _before = IERC20(_token).balanceOf(address(this));
        IGOFStrategy(_strategy).withdraw(_token);
        uint _after =  IERC20(_token).balanceOf(address(this));
        if (_after > _before) {
            uint _amount = _after.sub(_before);
            address _want = IGOFStrategy(_strategy).want();
            
            _before = IERC20(_want).balanceOf(address(this));
            IERC20(_token).safeApprove(onesplit, 0);
            IERC20(_token).safeApprove(onesplit, _amount);

            //swap by imdex
            address[] memory swap2TokenRouting;
            swap2TokenRouting[0] = _token;
            swap2TokenRouting[1] = wht;
            swap2TokenRouting[2] = _want;
            IMdexRouter(onesplit).swapExactTokensForTokens(_amount, 0, swap2TokenRouting, address(this), now.add(1800)); 
            
            _after = IERC20(_want).balanceOf(address(this));
            if (_after > _before) {
                _amount = _after.sub(_before);
                uint _reward = _amount.mul(split).div(max);
                earn(_want, _amount.sub(_reward));
                IERC20(_want).safeTransfer(rewards, _reward);
            }
        }
    }
    
    function withdraw(address _token, uint _amount) public {
        require(msg.sender == vaults[_token], "Golff:!vault");
        IGOFStrategy(strategies[_token]).withdraw(_amount);
    }
}