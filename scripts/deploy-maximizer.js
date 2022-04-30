// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

const addressesConfig = require('../addresses.config');
const addressConfig = addressesConfig[addressesConfig.current];

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');

  hre.ethernalSync = true;

  let accounts = await hre.ethers.getNamedSigners();
  let adminAddress = accounts["admin"].address;

  const CairoMaximizer = await hre.ethers.getContractFactory("CairoMaximizer");
  // deploy with token address
  const maximizer = await upgrades.deployProxy(CairoMaximizer, [addressConfig.TOKEN_PROXY_ADDRESS]);
  await maximizer.deployed();

  console.log("Maximizer deployed to:", maximizer.address);

  await maximizer.updateCompoundTax(5);
  await maximizer.updateInitialDeposit(ethers.BigNumber.from("0x0de0b6b3a7640000"));
  await maximizer.updateExitTax(10);
  await maximizer.updateMaxPayoutCap(ethers.BigNumber.from("500000000000000000000000"));
  await maximizer.updateRefBonus(ethers.BigNumber.from("10"));
  await maximizer.updateCairoTokenAddress(addressConfig.TOKEN_PROXY_ADDRESS);
  await maximizer.updatePayoutRate(ethers.BigNumber.from("1"));
  await maximizer.updateAdminFeeAddress(addressesConfig.mainnet.SPLIT_FEE_50, addressesConfig.mainnet.SPLIT_FEE_50_2);

  console.log("maximizer settings updated");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
