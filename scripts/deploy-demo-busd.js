// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

async function main() {
  await hre.run('compile');

  hre.ethernalSync = true;

  let accounts = await hre.ethers.getNamedSigners();
  let adminAddress = accounts["admin"].address;

  const DemoBUSDToken = await hre.ethers.getContractFactory("DemoBUSDToken");
  const token = await DemoBUSDToken.deploy();
  await token.deployed();

  console.log("Demo BUSD Token Deployed to:", token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
