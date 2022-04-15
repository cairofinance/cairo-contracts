//require("@nomiclabs/hardhat-ganache");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("hardhat-spdx-license-identifier");
require('hardhat-deploy');
require('hardhat-deploy-ethers');
require ('hardhat-abi-exporter');
require("@nomiclabs/hardhat-ethers");
require("dotenv/config")
require('@openzeppelin/hardhat-upgrades');
//require("@tenderly/hardhat-tenderly");

//require('hardhat-ethernal');

const { TOKENS } = require('./config/tokens.js');

let accounts = [];
var fs = require("fs");
var read = require('read');
var util = require('util');
const keythereum = require("keythereum");
const prompt = require('prompt-sync')();
var hardhatAccounts = {};
(async function() {
    try {
        const root = '.keystore';
        var pa = fs.readdirSync(root);
        for (let index = 0; index < pa.length; index ++) {
            let ele = pa[index];
            let fullPath = root + '/' + ele;
		    var info = fs.statSync(fullPath);
            //console.dir(ele);
		    if(!info.isDirectory() && ele.endsWith(".keystore")){
                const content = fs.readFileSync(fullPath, 'utf8');
                const json = JSON.parse(content);
                const password = prompt('Input password for 0x' + json.address + ': ', {echo: '*'});
                //console.dir(password);
                const privatekey = keythereum.recover(password, json).toString('hex');
                //console.dir(privatekey);
                accounts.push('0x' + privatekey);
                //console.dir(keystore);
		    }
	    }
    } catch (ex) {
    }
    try {
        const file = '.secret';
        var info = fs.statSync(file);
        if (!info.isDirectory()) {
            const content = fs.readFileSync(file, 'utf8');
            let lines = content.split('\n');
            for (let index = 0; index < lines.length; index ++) {
                let line = lines[index];
                if (line == undefined || line == '') {
                    continue;
                }
                if (!line.startsWith('0x') || !line.startsWith('0x')) {
                    line = '0x' + line;
                }
                accounts.push(line);
            }
        }
    } catch (ex) {
    }
})();

module.exports = {
    defaultNetwork: "localhardhat",
    abiExporter: {
        path: "./abi",
        clear: false,
        flat: true,
        // only: [],
        // except: []
    },
    namedAccounts: {
        deployer: {
            default: 0,
            97: '0x094b6B1d9cF962d2F87DFE5D16311a17e60E9f0e',
            56: '0x094b6B1d9cF962d2F87DFE5D16311a17e60E9f0e',
            1337: '0x094b6B1d9cF962d2F87DFE5D16311a17e60E9f0e'
        },
        admin: {
            default: 1,
            97: '0x9cda6543A9fe564A4BEB36042288dF6A0e547aD9',
            56: '0x9cda6543A9fe564A4BEB36042288dF6A0e547aD9',
            1337: '0x9cda6543A9fe564A4BEB36042288dF6A0e547aD9'
        },
        ecoReceiver: {
            default: 2,
            97: '0x3C4805c9a524Da7dD2062b95b6EAE974Ba9f54BB',
            56: '0x3C4805c9a524Da7dD2062b95b6EAE974Ba9f54BB',
        },
        teamReceiver: {
            default: 3,
            97: '0x3C4805c9a524Da7dD2062b95b6EAE974Ba9f54BB',
            56: '0x3C4805c9a524Da7dD2062b95b6EAE974Ba9f54BB',
        },
        feeTo: {
            default: 4,
            97: '0x9cda6543A9fe564A4BEB36042288dF6A0e547aD9',
            56: '0x9cda6543A9fe564A4BEB36042288dF6A0e547aD9',
            1337: '0x9cda6543A9fe564A4BEB36042288dF6A0e547aD9',
        },
    },
    networks: {
        mainnet: {
            url: `https://bsc-dataseed3.binance.org`,
            accounts: accounts,
            //gasPrice: 1.3 * 1000000000,
            chainId: 56,
            gasMultiplier: 1.5,
        },
        localtest: {
            url: `http://127.0.0.1:7545`,
            chainId: 1337,
            accounts: accounts,
            gasPrice: 1.3 * 1000000000,
            gasLimit: Infinity
        },
        localhardhat: {
            url: `http://127.0.0.1:8080`,
            chainId: 56,
            accounts: accounts,
            gasPrice: 1.3 * 1000000000,
            gasMultiplier: 1.5,
            gasLimit: 9999 * 1000000000
        },
        test: {
            url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
            accounts: accounts,
            //gasPrice: 1.3 * 1000000000,
            chainId: 97,
            tags: ["test"],
        },
        hardhat: {
            accounts: require('./.accountkeys'),
            forking: {
                enabled: true,
                url: `https://bsc-dataseed1.defibit.io/`
                //url: `https://bsc-dataseed1.ninicoin.io/`
                //url: `https://bsc-dataseed3.binance.org/`
                //url: `https://data-seed-prebsc-1-s1.binance.org:8545`
            },
            live: true,
            saveDeployments: true,
            tags: ["test", "local"],
            chainId: 56,
            timeout: 2000000,
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.8.4",
                settings: {
                    optimizer: {
                        enabled: false,
                        runs: 0,
                    },
                },
            }
        ],
    },
    spdxLicenseIdentifier: {
        overwrite: true,
        runOnCompile: true,
    },
    mocha: {
        timeout: 2000000,
    },
    etherscan: {
     apiKey: process.env.BSC_API_KEY,
   },
   tenderly: {
    username: "cairofinance",
    project: "CairoFinance"
   }
};

(function() {
    Object.assign(module.exports.namedAccounts, TOKENS);
})()
