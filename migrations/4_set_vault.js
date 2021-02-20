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
    console.log(`[GOF] Set GofVault, controller:${controller.address}`);
    const vaults = require(`../build/deployments.vaults.${network}.json`);
    for (token in vaults) {
        let vaultAddress  = vaults[token];
        let tokenAddress = knownContracts[token][network];
        if (!tokenAddress) {
            throw new Error(`Address of ${token} is not registered on migrations/known-contracts.js!`);
          }
        await controller.setVault(tokenAddress, vaultAddress);
        console.log(`[GOF] Token:${token}, VaultAddress:${vaultAddress}`);
    }
}