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

  const MgmtContract = await hre.ethers.getContractFactory("ManagementContract");
  // deploy with token address
  const mgmtcontract = await upgrades.deployProxy(MgmtContract, [addressConfig.TOKEN_PROXY_ADDRESS]);
  await mgmtcontract.deployed();

  console.log("management contract deployed");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
