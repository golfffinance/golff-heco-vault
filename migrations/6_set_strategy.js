// ++++++++++++++++ Define Contracts ++++++++++++++++ 
const knownContracts = require('./known-contracts');

const Controller = artifacts.require("GOFControllerV1");

// ++++++++++++++++  Main Migration ++++++++++++++++ 
const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deploy(deployer, network),
  ]);
};

module.exports = migration;

// ++++++++++++++++  Deploy Functions ++++++++++++++++ 
async function deploy(deployer, network) {
    const controller = await Controller.deployed();
    console.log(`[GOF] Set GofStragtegy, controller:${controller.address}`);
    const strategies = require(`../build/deployments.strategy.${network}.json`);
    for (token in strategies) {
        let stragtegyAddress  = strategies[token];
        let tokenAddress = knownContracts[token][network];
        if (!tokenAddress) {
            throw new Error(`Address of ${token} is not registered on migrations/known-contracts.js!`);
        }
        await controller.approveStrategy(tokenAddress, stragtegyAddress);
        await controller.setStrategy(tokenAddress, stragtegyAddress);
        console.log(`[GOF] Set Stragtegy Token:${token}, StragtegyAddress:${stragtegyAddress}`);
    }
}