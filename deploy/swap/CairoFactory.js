module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
}) {
    console.log("Starting");
    const {deploy} = deployments;
    //console.dir(deployments);
    let namedAccounts = await getNamedAccounts();
    let adminAcc = namedAccounts.admin;
    let feeToAcc = namedAccounts.feeTo;

    console.dir(feeToAcc);

   // const {admin, feeTo} = await getNamedAccounts();
 //   const {deployer, admin, feeToAd} = await ethers.getNamedSigners();
 const {deployer, admin, feeTo} = await ethers.getNamedSigners();

   // console.dir(admin);
   console.dir(feeTo);

    let deployResult = await deploy('CairoFactory', {
        from: deployer.address,
        args: [admin.address],
        log: true,
    });

    console.log("Set fee to: "+feeTo.address)

    let cairoFactory = await ethers.getContract('CairoFactory');
    //let cairoFactory = deployResult;
    let currentFeeTo = await cairoFactory.feeTo();
    if (currentFeeTo != feeTo.address) {
        tx = await cairoFactory.connect(admin).setFeeTo(feeTo.address);
        tx = await tx.wait();
        console.dir("set feeTo: " + feeTo);
        console.dir(tx);
    }
};

module.exports.tags = ['CairoFactory'];
module.exports.dependencies = [];
