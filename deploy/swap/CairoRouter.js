return; // FIXME

const { TOKEN } = require('../../config/address.js');
module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    upgrades
}) {
    const {deploy} = deployments;
    const {admin} = await getNamedAccounts();
    const {WBNB} = await getNamedAccounts();
    const {deployer} = await ethers.getNamedSigners();
    let cairoFactory = await ethers.getContract('CairoFactory');
    const routerFactory = await ethers.getContractFactory("CairoRouter");
    console.log("deployer address:"+deployer.address);
    console.log("Factory address: "+cairoFactory.address);

    let deployResult = await upgrades.deployProxy(routerFactory, {
        from: deployer.address,
        args: [cairoFactory.address, 0, WBNB],
        log: true,
    });
};

module.exports.tags = ['CairoRouter'];
module.exports.dependencies = ['CairoFactory'];
