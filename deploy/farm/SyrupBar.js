module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
}) {
    const {deploy} = deployments;
    const {deployer} = await ethers.getNamedSigners();

    let cairoToken = await ethers.getContract('CairoToken');
    let deployResult = await deploy('SyrupBar', {
        from: deployer.address,
        args: [cairoToken.address],
        log: true,
    });
};

module.exports.tags = ['SyrupBar'];
module.exports.dependencies = ['CairoToken'];
