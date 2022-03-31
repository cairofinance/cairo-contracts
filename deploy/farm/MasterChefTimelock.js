module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
}) {
    const {deploy} = deployments;
    const {deployer} = await ethers.getNamedSigners();

    let masterChef = await ethers.getContract('MasterChef');
    console.log("masterChef: ", masterChef.address);
    await deploy('MasterChefTimelock', {
        from: deployer.address,
        args: [masterChef.address, deployer.address, 60 * 60 * 48],
        log: true,
    });
    let currentPools = {
        '0xfA6160c7596d237fF2c13110d3Db6c45A259F9FC' : 0
    }
    let masterChefTimelock = await ethers.getContract('MasterChefTimelock');
    for (pool in currentPools) {
        let pid = currentPools[pool];
        //console.log(pool, pid);
        let exists = await masterChefTimelock.existsPools(pool);
        if (!exists) {
            tx = await masterChefTimelock.connect(deployer).addExistsPools(pool, pid);
            tx = await tx.wait();
            console.log("add exist pid " + pool + "," + pid);
            console.dir(tx);
        }
    }
    let currentAdmin = await masterChef.owner();
    if (currentAdmin != masterChefTimelock.address) {
        console.log("current Admin: " + currentAdmin);
        console.log("set Admin: " + masterChefTimelock.address);
        tx = await masterChef.connect(deployer).transferOwnership(masterChefTimelock.address);
        tx = await tx.wait();
        console.log("transfer master chef owner to " + masterChefTimelock.address);
        console.dir(tx);
    }
};

module.exports.tags = ['MasterChefTimelock'];
module.exports.dependencies = [];
