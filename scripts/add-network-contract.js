// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');

  //let accounts = await hre.ethers.getNamedSigners();
  //let adminAddress = accounts["admin"].address;

  const CairoToken = await hre.ethers.getContractFactory("CairoToken");
  const token = await CairoToken.attach("0xfA6160c7596d237fF2c13110d3Db6c45A259F9FC");

  await token.addNetworkContract("0xe0907B6E63E775150A8E45A2A3b431769912Fd1c");
  console.log("network contracted added");
   /*
  await hre.tenderly.persistArtifacts({
    name: "CairoToken",
    address: token.address
  });

  await hre.tenderly.verify({
      name: 'CairoToken',
      address: token.address
  });
  
*/
    // We get the contract to deploy
   /* const Greeter = await ethers.getContractFactory("CairoToken");
    const greeter = await Greeter.deploy();
  
    await greeter.deployed();

    await greeter.initialize("0x8D361826cfAFCabD54319D3aE16Bcd245a82253C");
  
    console.log("Greeter deployed to:", greeter.address);*/
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
