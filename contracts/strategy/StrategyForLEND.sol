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
import  "../interfaces/IGOFController.sol";
import  "../interfaces/mdex/IMdexRouter.sol";
import  "../interfaces/lendhub/ILendPool.sol";
import  "../interfaces/lendhub/ILendHTPool.sol";
import  "../interfaces/lendhub/IUnitroller.sol";
import  "../interfaces/IWHT.sol";
/*

 A strategy must implement the following calls;
 
 - deposit()
 - withdraw(address) must exclude any tokens used in the yield - Controller role - withdraw should return to Controller
 - withdraw(uint) - Controller | Vault role - withdraw should always return to vault
 - withdrawAll() - Controller | Vault role - withdraw should always return to vault
 - balanceOf()
 
 Where possible, strategies must remain as immutable as possible, instead of updating variables, we update the contract by linking it in the controller
 
*/

contract StrategyForLEND is IGOFStrategy, Ownable{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public want; //*
    address public output; //*
    address public lendPool; //*
    address public unitroller = address(0x6537d6307ca40231939985BCF7D83096Dd1B4C09);

    address constant public hgof = address(0x2AAFe3c9118DB36A20dd4A942b6ff3e78981dce1);
    address public constant wht = address(0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F);

    address public mdexRouter;

    uint public burnfee = 400;
    uint public fee = 100;
    uint public foundationfee = 400;
    uint public callfee = 100;
    
    uint constant public max = 1000;

    uint public withdrawalFee = 0;
    uint constant public withdrawalMax = 10000;
    
    address public strategyDev;
    address public controller;
    address public foundationAddress = address(0x79006B8548326C71bbF57a4384843Df2f578381F);
    address public burnAddress;

    string public getName;

    address[] public swap2GOFRouting;
    address[] public swap2TokenRouting;

    constructor(address _controller, 
            address _want,
            address _output,
            address _poolAddress,
            address _routerAddress,
            address _burnAddress) public {
        strategyDev = tx.origin;
        controller = _controller;
        burnAddress = _burnAddress;
        want = _want;
        output = _output;
        getName = string(abi.encodePacked("Golff:Strategy:", ERC20(want).name()));
        lendPool = _poolAddress;
        mdexRouter = _routerAddress;
        
        swap2GOFRouting = [output, hgof];
        swap2TokenRouting = [output, want];
        doApprove();
    }

    function getWant() external view override returns (address){
        return want;
    }

    function doApprove () public{
        IERC20(output).safeApprove(mdexRouter, 0);
        IERC20(output).safeApprove(mdexRouter, uint(-1));
    }
    
    function deposit() public override {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            if (want == wht) {
                IWHT(wht).withdraw(_want);
                uint balance = address(this).balance;
                if (balance > 0) {
                    ILendHTPool(lendPool).mint{value: balance}();
                }
            } else {
                IERC20(want).safeApprove(lendPool, 0);
                IERC20(want).safeApprove(lendPool, _want);
                require(ILendPool(lendPool).mint(_want) == 0, "Strategy mint:error");
            }
        }
    }
    
    // Controller only function for creating additional rewards from dust
    function withdraw(address _asset) external override{
        require(msg.sender == controller, "Golff:!controller");
        require(want != address(_asset), "Golff:want");
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        IERC20(_asset).safeTransfer(controller, balance);
    }
    
    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint _amount) external override {
        require(msg.sender == controller, "Golff:!controller");
        uint _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        
        uint _fee = 0;
        if (withdrawalFee>0){
            _fee = _amount.mul(withdrawalFee).div(withdrawalMax);        
            IERC20(want).safeTransfer(IGOFController(controller).getRewards(), _fee);
        }
        
        address _vault = IGOFController(controller).getVaults(address(want));
        require(_vault != address(0), "Golff:!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, _amount.sub(_fee));
    }
    
    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external override returns (uint balance) {
        require(msg.sender == controller, "Golff:!controller");
        _withdrawAll();
        
        
        balance = IERC20(want).balanceOf(address(this));
        
        address _vault = IGOFController(controller).getVaults(address(want));
        require(_vault != address(0), "Golff:!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, balance);
    }
    
    function _withdrawAll() internal {
        uint256 balance = ILendPool(lendPool).balanceOf(address(this));
        if(balance > 0){
            uint result = ILendPool(lendPool).redeem(balance);
            require(result == 0, "Strategy redeem:error");
        }
    }
    
    modifier checkStrategist(){
        require(msg.sender == strategyDev || msg.sender == owner(), "Golff:!strategist");
        _;
    }

    function harvest() external checkStrategist{
        //获取收益
        getReward();
        //判断收益情况
        doswap();
        //分hgof
        dosplit();
        //复投
        deposit();
    }

    function doswap() internal {
        uint256 _balance = IERC20(output).balanceOf(address(this));
        if(_balance > 0){
            uint256 _2token = 0;
            if(output != want){
                _2token = _balance.mul(91).div(100); //91%
                if(_2token > 0){
                    IMdexRouter(mdexRouter).swapExactTokensForTokens(_2token, 0, swap2TokenRouting, address(this), now.add(1800));
                }
                uint256 _2gof = _balance.sub(_2token);  //9%
                if(_2gof > 0 ){
                    IMdexRouter(mdexRouter).swapExactTokensForTokens(_2gof, 0, swap2GOFRouting, address(this), now.add(1800));
                }
            }else{
                uint256 _2gof = _balance.mul(9).div(100);  //9%
                if(_2gof > 0 ){
                    IMdexRouter(mdexRouter).swapExactTokensForTokens(_2gof, 0, swap2GOFRouting, address(this), now.add(1800));
                }
            }
        }
    }

    function dosplit() internal{
        uint b = IERC20(hgof).balanceOf(address(this));
        if(b > 0){
            uint _fee = b.mul(fee).div(max);
            uint _callfee = b.mul(callfee).div(max);
            uint _foundationfee = b.mul(foundationfee).div(max);
            IERC20(hgof).safeTransfer(IGOFController(controller).getRewards(), _fee);
            IERC20(hgof).safeTransfer(msg.sender, _callfee); 
            IERC20(hgof).safeTransfer(foundationAddress, _foundationfee); 

            if (burnfee >0){
                uint _burnfee = b.mul(burnfee).div(max); 
                IERC20(hgof).safeTransfer(burnAddress, _burnfee);
            }
        }
    }

    function _withdrawSome(uint256 _amount) internal returns (uint256) {
        uint256 before = IERC20(want).balanceOf(address(this));
        if (want == wht) {
            require(ILendHTPool(lendPool).redeemUnderlying(_amount) == 0, "Strategy redeemUnderlying:error");
            uint balance = address(this).balance;
            if (balance > 0) {
                IWHT(want).deposit{value: balance}();
            }
        } else {
            require(ILendPool(lendPool).redeemUnderlying(_amount) == 0, "Strategy redeemUnderlying:error");
        }
        return IERC20(want).balanceOf(address(this)).sub(before);
    }

    function getReward() internal {
        address[] memory markets = new address[](1);
        markets[0] = lendPool;
        IUnitroller(unitroller).claimComp(address(this), markets);
    }
    
    function balanceOfWant() internal view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }
    
    function balanceOfPool() internal view returns (uint) {
        (, uint256 poolBal, , uint256 exchangeRate) =
            ILendPool(lendPool).getAccountSnapshot(address(this));
        return poolBal.mul(exchangeRate).div(1e18);
    }
    
    function balanceOf() external view override returns (uint) {
        return balanceOfWant()
               .add(balanceOfPool());
    }
    
    function setController(address _controller) public onlyOwner{
        controller = _controller;
    }
    
    function setFees(uint256 _fee, uint256 _callfee, uint256 _burnfee, uint256 _foundationfee) public onlyOwner{
        require(max == _fee.add(_callfee).add(_burnfee).add(_foundationfee), "Invalid fees");

        fee = _fee;
        callfee = _callfee;
        burnfee = _burnfee;
        foundationfee = _foundationfee;
    }

    function setFoundationAddress(address _foundationAddress) public onlyOwner{
        foundationAddress = _foundationAddress;
    }

    function setWithdrawalFee(uint _withdrawalFee) public onlyOwner{
        require(_withdrawalFee <=100,"fee > 1%"); //max:1%
        withdrawalFee = _withdrawalFee;
    }
    
    function setBurnAddress(address _burnAddress) public onlyOwner{
        burnAddress = _burnAddress;
    }

    function setStrategyDev(address _strategyDev) public onlyOwner{
        strategyDev = _strategyDev;
    }

    function setRouter(address _routerAddress) public onlyOwner{
        mdexRouter = _routerAddress;
    }

    function setSwap2GOF(address[] memory _path) public onlyOwner{
        swap2GOFRouting = _path;
    }

    function setSwap2Token(address[] memory _path) public onlyOwner{
        swap2TokenRouting = _path;
    }

    function setUnitroller(address _unitrollerAddress) public onlyOwner{
        unitroller = _unitrollerAddress;
    }

    receive() external payable {}
}