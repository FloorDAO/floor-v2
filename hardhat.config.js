/** @type import('hardhat/config').HardhatUserConfig */
var fs = require('fs');
require('dotenv').config();
require('hardhat-gas-reporter');
require('hardhat-preprocessor');
require('@nomiclabs/hardhat-waffle');


function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

module.exports = {
  networks: {
    mainnet: {
      url: process.env.MAINNET_RPC_URL,
      accounts: [`0x${process.env.DEV_PRIVATE_KEY}`],
      timeout: 60000
    },
  },
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  preprocess: {
    eachLine: (hre) => ({
      transform: (line) => {
        if (line.match(/^\s*import /i)) {
          for (let [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    cache: './cache_hardhat',
    sources: './src',
    tests: './test/hardhat'
  },
};
