const { TOKEN } = require('../../config/address.js');
module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
}) {
    const {deploy} = deployments;
    const {admin, bottle, vault} = await getNamedAccounts();
    const {WBNB, USDT} = await getNamedAccounts();
    const {deployer} = await ethers.getNamedSigners();
    let cairoRouter = await ethers.getContract('CairoRouter');
    let cairoFactory = await ethers.getContract('CairoFactory');
    let cairoToken = await ethers.getContract('CairoToken');

    let WBNBToken = null;
    let USDTToken = null;
    if (!hre.network.tags.local && !hre.network.tags.test) {
        WBNBToken = await ethers.getContractAt('MockToken', WBNB); 
        USDTToken = await ethers.getContractAt('MockToken', USDT);
    } else {
        WBNBToken = await ethers.getContract('MockToken_WBNB');
        USDTToken = await ethers.getContract('MockToken_USDT');
    }

    let deployResult = await deploy('CairoFinanceFee', {
        from: deployer.address,
        args: [bottle, vault, cairoRouter.address, cairoFactory.address, WBNBToken.address, cairoToken.address, USDTToken.address, deployer.address],
        log: true,
    });
};

module.exports.tags = ['SwapFee'];
module.exports.dependencies = ["CairoToken"];
