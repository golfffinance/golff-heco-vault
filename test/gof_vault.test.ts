import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { solidity } from 'ethereum-waffle';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import vaults from "../build/deployments.vaults.test-0220.json";

chai.use(solidity);

describe('GofVault Test', () =>{

    const ETH = ethers.utils.parseEther('1');
    const { provider } = ethers;

    let operator: SignerWithAddress;
    before('Provider & Accounts setting', async () => {
        [operator] = await ethers.getSigners();
    });

    let G_HBTC: Contract;
    before('Get Contract Instance', async () => {
        G_HBTC = await ethers.getContractAt('GOFVault', vaults['HBTC']);
    });

    describe('#HBTC',()=>{

        it('#withdraw', async ()=>{
            const balance = await G_HBTC.balanceOf(operator.address);
            console.log(`BalanceOf:${balance}`);
            const amount = ETH.mul(10);
            await G_HBTC.connect(operator).withdraw(amount);
        })
    })
})

