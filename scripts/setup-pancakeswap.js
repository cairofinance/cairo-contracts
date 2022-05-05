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
  // hre.ethernalSync = true;

  let accounts = await hre.ethers.getNamedSigners();
  let adminAddress = accounts["admin"].address;

  const CairoToken = await hre.ethers.getContractFactory("CairoToken");
  // deploy with token address
  const token = await CairoToken.attach(addressConfig.TOKEN_PROXY_ADDRESS);

  console.log("Setup pancake on: ", token.address);
  /*await token.setAdminFeeAddresses(addressConfig.SPLIT_FEE_50, addressConfig.SPLIT_FEE_50_2);
  await token.setupPancakeV1();*/
  // await token.addKnownPairAddress("0xa27B6413E92F4828355eF4B3E7A09c959bcD123b");
  // await token.addTaxExcludedAddress("0x3C4805c9a524Da7dD2062b95b6EAE974Ba9f54BB");
  var pairs = await token.getPairs();
  console.dir(pairs);
  console.log("done");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
