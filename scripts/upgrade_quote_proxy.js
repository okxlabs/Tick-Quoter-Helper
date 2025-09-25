const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "";
  
  const QueryData = await ethers.getContractFactory("QueryData");
  await upgrades.upgradeProxy(proxyAddress, QueryData);
  
  console.log("new implementation address:", await upgrades.erc1967.getImplementationAddress(proxyAddress));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("upgrade failed:", error);
    process.exit(1);
  });
