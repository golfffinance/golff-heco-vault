// ++++++++++++++++ Define Contracts ++++++++++++++++ 
const {FUNDATION_ADDRESS, BURN_ADDRESS, GOF_STRATEGY } = require('./config');
const knownContracts = require('./known-contracts');
const {writeLog} = require('./log');

const Controller = artifacts.require("GOFControllerV1");
const StrategyForMDEX = artifacts.require("StrategyForMDEX");
// ++++++++++++++++  Main Migration ++++++++++++++++ 
const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deploy(deployer, network),
  ]);
};

module.exports = migration;

// ++++++++++++++++  Deploy Functions ++++++++++++++++ 
async function deploy(deployer, network) {
    const deployments = {};
    const controller = await Controller.deployed();
    console.log(`[GOF] Deploy GofStrategy, controller:${controller.address}`);
    for await (const { pid, token, output } of GOF_STRATEGY) {
        let tokenAddress = knownContracts[token][network];
        if (!tokenAddress) {
          throw new Error(`Address of ${token} is not registered on migrations/known-contracts.js!`);
        }
        let outputAddress = knownContracts[output][network];
        if (!outputAddress) {
          throw new Error(`Address of ${output} is not registered on migrations/known-contracts.js!`);
        }
        //  uint256 _pid, address _want, address _output, address _burnAddress
        await deployer.deploy(StrategyForMDEX, controller.address, pid, tokenAddress, outputAddress, BURN_ADDRESS);
        console.log(`[GOF] Deploy GofStrategy[${token}] = ${StrategyForMDEX.address}`);
        deployments[token] = StrategyForMDEX.address;
    }
    await writeLog(deployments, 'strategy', network);
}