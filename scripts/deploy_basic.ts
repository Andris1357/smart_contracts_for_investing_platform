import { ContractFactory } from "ethers";
import { hexStripZeros } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { Contract } from "hardhat/internal/hardhat-network/stack-traces/model";

async function main() {
    const locked_amount = ethers.utils.parseEther("1");

    const Contract_Factory: ContractFactory = await ethers.getContractFactory("FloatTest"); // BasicChild
    let Deployed_contract: any|Contract;
    Deployed_contract = await Contract_Factory.deploy(
        { value: locked_amount }
    );
    await Deployed_contract.deployed();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
