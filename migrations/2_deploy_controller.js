// ++++++++++++++++ Define Contracts ++++++++++++++++ 
const { REWARD_ADDRESS } = require('./config');
const Controller = artifacts.require("GOFControllerV1");
const {writeLog} = require('./log');
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
    await deployer.deploy(Controller, REWARD_ADDRESS);
    deployments['Controller'] = Controller.address;
    await writeLog(deployments, 'controller', network);
}