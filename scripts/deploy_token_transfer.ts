import { ContractFactory } from "ethers";
import { hexStripZeros } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { Contract } from "hardhat/internal/hardhat-network/stack-traces/model";

async function main() {
    const lockedAmount = ethers.utils.parseEther("1");

    const Basic_factory: ContractFactory = await ethers.getContractFactory("BasicChild");
    const Basic_instance = await Basic_factory.deploy( {value: lockedAmount} );
    await Basic_instance.deployed();

    const Token_factory: ContractFactory = await ethers.getContractFactory("Ierc20Test3");
    const Token_instance = await Token_factory.deploy();
    var transaction = await Token_instance.transfer(Basic_instance.address, 10)
    let balances = [
        Token_instance.balanceOf(Basic_instance.address),
        Token_instance.balanceOf(Token_instance.address)
    ]
    console.log(`Token balances: ${balances.map(async function (balance) {
        await balance
    })}`)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
