require("@nomiclabs/hardhat-etherscan")
require('dotenv').config();
const {scriptionId } = process.env;
module.exports = [
    scriptionId 
];
//npx hardhat verify --constructor-args scripts/verify.js 0x79de48641CDA52BED6566e119AB2E9669dfa1FE0  --network rinkeby --show-stack-traces 

