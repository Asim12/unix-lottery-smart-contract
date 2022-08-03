
require('dotenv').config();
const {scriptionId} = process.env;
async function main() {
    const Contract = await ethers.getContractFactory("VRFv2Consumer")
    const contractInstance = await Contract.deploy(
        scriptionId 
    )
    console.log(`Contract deployed to "${contractInstance.address}"`);
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })