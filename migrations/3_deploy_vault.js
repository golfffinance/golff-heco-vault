// ++++++++++++++++ Define Contracts ++++++++++++++++ 
const { GOF_VAULT } = require('./config');
const knownContracts = require('./known-contracts');
const {writeLog} = require('./log');

const Controller = artifacts.require("GOFControllerV1");
const GOFVault = artifacts.require("GOFVault");
const GOFVaultHT = artifacts.require("GOFVaultHT");

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
    console.log(`[GOF] Deploy GofVault, controller:${controller.address}`);
    for await (const { token, symbol, earnLowerlimit } of GOF_VAULT) {
        let tokenAddress = knownContracts[token][network];
        if (!tokenAddress) {
          throw new Error(`Address of ${token} is not registered on migrations/known-contracts.js!`);
        }
        await deployer.deploy(GOFVault, tokenAddress, symbol, controller.address, earnLowerlimit);
        console.log(`[GOF] Deploy GofVault[${token}] = ${GOFVault.address}`);
        deployments[token] = GOFVault.address;
    }

    console.log(`[GOF] Deploy GofVaultHT, controller:${controller.address}`);
    const tokenAddress = knownContracts['WHT'][network];
    if (!tokenAddress) {
        throw new Error(`Address of WHT is not registered on migrations/known-contracts.js!`);
      }
    await deployer.deploy(GOFVaultHT, tokenAddress, controller.address);
    deployments['WHT'] = GOFVaultHT.address;
    console.log(`[GOF] Deploy GOFVaultHT = ${GOFVaultHT.address}`);

    await writeLog(deployments, 'vaults', network);
}