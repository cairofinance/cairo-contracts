const { TOKEN } = require('../../config/address.js');
module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
}) {
    const {deploy} = deployments;
    const {admin} = await getNamedAccounts();
    const {WBNB} = await getNamedAccounts();
    const {deployer} = await ethers.getNamedSigners();
    let cairoFactory = await ethers.getContract('CairoFactory');
    let deployResult = await deploy('CairoRouter', {
        from: deployer.address,
        args: [cairoFactory.address, WBNB],
        log: true,
    });
};

module.exports.tags = ['CairoRouter'];
module.exports.dependencies = ['CairoFactory'];
