import { ContractFactory } from "ethers";
import { hexStripZeros } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { Contract } from "hardhat/internal/hardhat-network/stack-traces/model";

async function main() {
  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  // const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS;
  const locked_amount = ethers.utils.parseEther("1");

  let contract_names: Array<string> = ["PRBMathTest", "BasicChild", "Ierc20Test3", "RewardPool", "Channels", "Investing"]; 
  const contract_index = 3;
  let contract_params: Array<string|number> = [];
  var is_token: boolean = true;
  
  const Contract_Factory: ContractFactory = await ethers.getContractFactory(contract_names[contract_index]);
  let Deployed_contract: any|Contract;
  if (is_token) {
    Deployed_contract = await Contract_Factory.deploy(...contract_params); // I: for token type contracts there is no 'value' param
  } else {
    Deployed_contract = await Contract_Factory.deploy(
      ...contract_params, 
      { value: locked_amount }
    );
  }
  await Deployed_contract.deployed();
  // console.log(`Contract ${contract_names[contract_index]} ${is_token ? '' : 'with' + locked_amount + 'ETH'} deployed to:`, Deployed_contract.address);
  // var function_call = await Deployed_contract.transfer("0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 10) //channelBasic(10);
  // var stored_var_ = await Deployed_contract.stored_recipient();
  // ethers.getContractAt("[contract name]", "[contract address]")
  // ethers.getSigners
  // console.log(`Contract function called with signature ${function_call}, result ${stored_var_}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
