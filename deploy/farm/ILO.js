const { ITEMS } = require('../../config/ilo.js');
const BigNumber = require('bignumber.js');
module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
}) {
    const {deploy} = deployments;
    const {deployer} = await ethers.getNamedSigners();
    let accounts = await getNamedAccounts();

    let cairoToken = await ethers.getContract("CairoToken");
    let currentBlockNumber = await ethers.provider.getBlockNumber();

    if (hre.network.tags.local || hre.network.tags.test) {
        currentBlockNumber = 9300998;
    }
    let deployResult = await deploy('ILO', {
        from: deployer.address,
        args: [cairoToken.address, currentBlockNumber, currentBlockNumber + 20 * 60 * 24],
        log: true,
    });
    let USDT = accounts['USDT'];
    let cairoFactory = await ethers.getContract('CairoFactory');
    let ilo = await ethers.getContract('ILO');
    let totalAllocPoint = new BigNumber('0');
    for (let i = 0; i < ITEMS.length; i ++) {
        let item = ITEMS[i];
        console.dir(item);
        let token = accounts[item.token];
        //console.dir(token);
        let allocPoint = new BigNumber(item.percent.substring(0, item.percent.length - 1)).times(new BigNumber("10000")).toString();
        //console.dir(allocPoint);
        //console.log(token, USDT);
        let pair = await cairoFactory.expectPairFor(token, USDT);
        totalAllocPoint = totalAllocPoint.plus(new BigNumber(item.percent.substring(0, item.percent.length - 1)).times(new BigNumber("10000")));
        console.log(i, pair);
        let tx = await ilo.connect(deployer).add(allocPoint, pair);
        tx = await tx.wait();
        console.dir("add pair " + pair + "(" + item.token + ")" + " to ILO");
        console.dir(tx);
    }
    console.log(totalAllocPoint.toString());
    let balance = await cairoToken.balanceOf(ilo.address);
    /*
    if (balance.toString() == '0') {
        let tx = await cairoToken.connect(deployer).mintFor(ilo.address, '10000000000000000000000000');
        tx = await tx.wait();
        console.dir("mint 10000000000000000000000000 CAIRO to ILO");
        console.dir(tx);
    }
    */
};

module.exports.tags = ['ILO'];
module.exports.dependencies = ['CairoToken', 'CairoFinance'];
