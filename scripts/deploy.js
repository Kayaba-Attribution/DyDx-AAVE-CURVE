// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");


async function main() {

  let DyDxFalshloan;
  let wethContract;

  const[deployer] = await ethers.getSigners();

  const wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  const wethABI = [
    "function balanceOf(address deployer) view returns (uint256)",
    "function transfer(address dst, uint wad) public returns (bool)",
  ]

  console.log("Deploying contracts with the account:", deployer.address);

  // dydx has comments FlashLoanNoComments does not
  //const DyDxFalshloanFactory = await hre.ethers.getContractFactory("dydx");
  const DyDxFalshloanFactory = await hre.ethers.getContractFactory("FlashLoanNoComments");

  DyDxFalshloan = await DyDxFalshloanFactory.deploy();
  await DyDxFalshloan.deployed();

  console.log("DyDxflashloan deployed to:", DyDxFalshloan.address);

  wethContract = new ethers.Contract(wethAddress, wethABI, deployer);
  console.log("Connected to WETH contract")

  await deployer.sendTransaction({ to: wethAddress, value: 10 });
  await wethContract.transfer(DyDxFalshloan.address, 10)
  console.log("Fund the contract 10 WETH wei ( fees )")
  console.log("Flashloan contract has:", (await wethContract.balanceOf(DyDxFalshloan.address)).toString(), "WETH wei")

  console.log("Run flashLoan!!!")
  await DyDxFalshloan.flashLoan(ethers.utils.parseEther("20000.0"))

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
