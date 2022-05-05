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
 // hre.ethernalWorkspace = 'Local Testnet';
  //hre.ethernalTrace = true;
 // hre.ethernalResetOnStart = 'Hardhat';

  // We get the contract to deploy

 // await network.provider.send("evm_setAutomine", [true]);
/*
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x8D361826cfAFCabD54319D3aE16Bcd245a82253C"],
  });
*/
  //console.dir(ethers);
//const deployer = await hre.ethers.getNamedSigners();
//console.dir(deployer);
/*
await network.provider.send("hardhat_setBalance", [
  "0x094b6B1d9cF962d2F87DFE5D16311a17e60E9f0e",
  "0x5538267900000000",
]);
*/
  let accounts = await hre.ethers.getNamedSigners();
  let adminAddress = accounts["admin"].address;

  const CairoToken = await hre.ethers.getContractFactory("CairoToken");
  const token = await CairoToken.attach(addressConfig.TOKEN_PROXY_ADDRESS);
  console.log("CairoToken at: ", token.address);
  //await token.initialize();
  let symbol = await token.symbol();
  console.log("token symbol: "+symbol);
  //await token.
}
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
