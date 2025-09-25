const { ethers, upgrades } = require("hardhat");

async function main() {
  const QueryData = await ethers.getContractFactory("QueryData");
  
  const proxy = await upgrades.deployProxy(
    QueryData, []
  );
  
  await proxy.deployed();
  
  console.log("proxy address:", proxy.address);
  console.log("implementation address:", await upgrades.erc1967.getImplementationAddress(proxy.address));
  console.log("admin address:", await upgrades.erc1967.getAdminAddress(proxy.address));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
