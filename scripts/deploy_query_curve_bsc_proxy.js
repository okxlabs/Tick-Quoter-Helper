const { ethers, upgrades } = require("hardhat");

async function main() {
  const QueryCurveUpgradeableBsc = await ethers.getContractFactory(
    "QueryCurveUpgradeableBsc"
  );

  const owner = process.env.OWNER_ADDRESS;
  if (!owner) {
    throw new Error("Missing owner address. Set OWNER_ADDRESS env var");
  }

  const proxy = await upgrades.deployProxy(QueryCurveUpgradeableBsc, [owner]);

  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();

  console.log("QueryCurveUpgradeableBsc proxy address:", proxyAddress);
  console.log(
    "QueryCurveUpgradeableBsc implementation address:",
    await upgrades.erc1967.getImplementationAddress(proxyAddress)
  );
  console.log(
    "QueryCurveUpgradeableBsc admin address:",
    await upgrades.erc1967.getAdminAddress(proxyAddress)
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
