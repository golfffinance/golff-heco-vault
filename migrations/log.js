const fs = require('fs');
const path = require('path');
const util = require('util');

const writeFile = util.promisify(fs.writeFile);

/**
 * 记录合约发布地址
 * @param {*} deployments json
 * @param {*} type 类型
 * @param {*} network 网络
 */
async function writeLog(deployments, type, network){
    const deploymentPath = path.resolve(__dirname, `../build/deployments.${type}.${network}.json`);
    await writeFile(deploymentPath, JSON.stringify(deployments, null, 2));
    console.log(`Exported deployments into ${deploymentPath}`);
}

module.exports = {
    writeLog
}