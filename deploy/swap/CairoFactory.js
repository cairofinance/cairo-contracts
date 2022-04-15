module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
}) {
    console.log("Starting");
    const {deploy} = deployments;
    console.dir(deployments);
    const {admin, feeTo} = await getNamedAccounts();
    const {deployer} = await ethers.getNamedSigners();

    console.dir(admin);

    let deployResult = await deploy('CairoFactory', {
        from: deployer.address,
        args: [admin],
        log: true,
    });

    let cairoFactory = await ethers.getContract('CairoFactory');
    let currentFeeTo = await cairoFactory.feeTo();
    if (currentFeeTo != feeTo) {
        tx = await cairoFactory.connect(deployer).setFeeTo(feeTo);
        tx = await tx.wait();
        console.dir("set feeTo: " + feeTo);
        console.dir(tx);
    }
};

module.exports.tags = ['CairoFactory'];
module.exports.dependencies = [];
