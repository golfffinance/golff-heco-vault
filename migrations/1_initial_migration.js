const Migrations = artifacts.require("Migrations");
const Artifactor = require('@truffle/artifactor');
const artifactor = new Artifactor(`${__dirname}/../build/contracts`);

 // import external contracts
const InitialArtifacts = {
 
};

module.exports = async function (deployer) {
  for await ([contractName, legacyArtifact] of Object.entries(InitialArtifacts)) {
    await artifactor.save({
      contractName,
      ...legacyArtifact,
    });
  }
  await deployer.deploy(Migrations);
};

