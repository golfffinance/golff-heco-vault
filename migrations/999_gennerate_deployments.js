const { writeLog } = require('./log');

const exportedContracts = [
  'GOFControllerV1'
];

// ++++++++++++++++  Main Migration ++++++++++++++++ 
const migration = async (deployer, network, accounts) => {

  const deployments = {};

  for (const name of exportedContracts) {
    const contract = artifacts.require(name);
    deployments[name] = {
      address: contract.address,
      abi: contract.abi,
    };
  }

  await writeLog(deployments,'contracts', network);
};

module.exports = migration;
