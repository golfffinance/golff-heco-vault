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
import  "../interfaces/mdex/IHecoPool.sol";
/*

 A strategy must implement the following calls;
 
 - deposit()
 - withdraw(address) must exclude any tokens used in the yield - Controller role - withdraw should return to Controller
 - withdraw(uint) - Controller | Vault role - withdraw should always return to vault
 - withdrawAll() - Controller | Vault role - withdraw should always return to vault
 - balanceOf()
 
 Where possible, strategies must remain as immutable as possible, instead of updating variables, we update the contract by linking it in the controller
 
*/

contract StrategyForMDEX is Ownable{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    address  public want; //husd
    address  public output; //mdex
    address constant public mdexrouter = address(0xbb87D38beEecac5eB602791703763722e3E9F359);
    address constant public wht = address(0x8543A3E99174913cEeaF8b10e890bC99c4a89420);

    address constant public gof = address(0xE2Ff1094BbcAb39077388E858d196BCE57f51428);
    //ETH  0x64FF637fB478863B7468bc97D30a5bF3A428a1fD
    address constant public usdt = address(0xF813DC9A98960E4D1FA76b3E18aCA2a92e515e91);
    address constant public hecoPool = address(0x1beec8956c37fCD4181CD1161E02A7EF4B974fE0);
    
    uint public burnfee = 400;
    uint public fee = 100;
    uint public foundationfee = 400;
    uint public callfee = 100;
    uint public pid;
    
    uint constant public max = 1000;

    uint public withdrawalFee = 0;
    uint constant public withdrawalMax = 10000;
    
    address public strategyDev;
    address public controller;
    address public foundationAddress = address(0x1250E38187Ff89d05f99F3fa0E324241bbE2120C);
    address public burnAddress;

    string public getName;

    address[] public swap2GOFRouting;
    address[] public swap2TokenRouting;
    
    
    constructor(address _controller, 
            uint256 _pid, 
            address _want,
            address _output, 
            address _burnAddress) public {
        strategyDev = tx.origin;
        controller = _controller;
        burnAddress = _burnAddress;
        pid = _pid;
        want = _want;
        output = _output;
        getName = string(abi.encodePacked("Golff:Strategy:", ERC20(want).name()));
        
        swap2GOFRouting = [output,usdt,gof];
        swap2TokenRouting = [output,usdt,want];
        doApprove();
    }

    function doApprove () public{
        IERC20(output).safeApprove(mdexrouter, 0);
        IERC20(output).safeApprove(mdexrouter, uint(-1));
    }
    
    function deposit() public {
        uint _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).safeApprove(hecoPool, 0);
            IERC20(want).safeApprove(hecoPool, _want);
            IHecoPool(hecoPool).deposit(pid, _want);

            doHarvest();
        }
    }
    
    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint balance) {
        require(msg.sender == controller, "Golff:!controller");
        require(want != address(_asset), "Golff:want");
        balance = _asset.balanceOf(address(this));
        _asset.safeTransfer(controller, balance);
    }
    
    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint _amount) external {
        require(msg.sender == controller, "Golff:!controller");
        uint _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }
        
        uint _fee = 0;
        if (withdrawalFee>0){
            _fee = _amount.mul(withdrawalFee).div(withdrawalMax);        
            IERC20(want).safeTransfer(IGOFController(controller).rewards(), _fee);
        }
        
        address _vault = IGOFController(controller).vaults(address(want));
        require(_vault != address(0), "Golff:!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, _amount.sub(_fee));
    }
    
    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint balance) {
        require(msg.sender == controller, "Golff:!controller");
        _withdrawAll();
        
        
        balance = IERC20(want).balanceOf(address(this));
        
        address _vault = IGOFController(controller).vaults(address(want));
        require(_vault != address(0), "Golff:!vault"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_vault, balance);
    }
    
    function _withdrawAll() internal {
        uint256 balance = balanceOfPool();
        if(balance > 0){
            IHecoPool(hecoPool).withdraw(pid, balance);
            doHarvest();
        }
    }
    
    function doHarvest() internal {
        //判断收益情况
        doswap();
        dosplit();//分gof
    }

    function doswap() internal {
        uint256 _balance = IERC20(output).balanceOf(address(this));
        if(_balance > 0){
            uint256 _2token = _balance.mul(90).div(100); //90%
            uint256 _2gof = _balance.mul(10).div(100);  //10%
            IMdexRouter(mdexrouter).swapExactTokensForTokens(_2token, 0, swap2TokenRouting, address(this), now.add(1800));
            IMdexRouter(mdexrouter).swapExactTokensForTokens(_2gof, 0, swap2GOFRouting, address(this), now.add(1800));
        }
    }

    function dosplit() internal{
        uint b = IERC20(gof).balanceOf(address(this));
        if(b > 0){
            uint _fee = b.mul(fee).div(max);
            uint _callfee = b.mul(callfee).div(max);
            uint _foundationfee = b.mul(foundationfee).div(max);
            IERC20(gof).safeTransfer(IGOFController(controller).rewards(), _fee);
            IERC20(gof).safeTransfer(msg.sender, _callfee); 
            IERC20(gof).safeTransfer(foundationAddress, _foundationfee); 

            if (burnfee >0){
                uint _burnfee = b.mul(burnfee).div(max); 
                IERC20(gof).safeTransfer(burnAddress, _burnfee);
            }
        }
    }
    
    function _withdrawSome(uint256 _amount) internal returns (uint) {
        IHecoPool(hecoPool).withdraw(pid, _amount);
        doHarvest();
        return _amount;
    }
    
    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }
    
    function balanceOfPool() public view returns (uint) {
       (uint256 amount, , ) = IHecoPool(hecoPool).userInfo(pid, address(this));
        return amount;
    }
    
    function balanceOf() public view returns (uint) {
        return balanceOfWant()
               .add(balanceOfPool());
    }
    

    function setController(address _controller) external onlyOwner{
        controller = _controller;
    }
    
    function setFees(uint256 _fee, uint256 _callfee, uint256 _burnfee, uint256 _foundationfee) external onlyOwner{
        require(max == _fee.add(_callfee).add(_burnfee).add(_foundationfee), "Invalid fees");

        fee = _fee;
        callfee = _callfee;
        burnfee = _burnfee;
        foundationfee = _foundationfee;
    }

    function setFoundationAddress(address _foundationAddress) public onlyOwner{
        foundationAddress = _foundationAddress;
    }

    function setWithdrawalFee(uint _withdrawalFee) external onlyOwner{
        require(_withdrawalFee <=100,"fee > 1%"); //max:1%
        withdrawalFee = _withdrawalFee;
    }
    
    function setBurnAddress(address _burnAddress) public onlyOwner{
        burnAddress = _burnAddress;
    }

    function setStrategyDev(address _strategyDev) public onlyOwner{
        strategyDev = _strategyDev;
    }

    function setSwap2GOF(address[] memory _path) public onlyOwner{
        swap2GOFRouting = _path;
    }
    function setSwap2Token(address[] memory _path) public onlyOwner{
        swap2TokenRouting = _path;
    }
}