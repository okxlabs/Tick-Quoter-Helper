const { ethers, upgrades } = require("hardhat");

async function main() {
  const baseQueryProxyAddress = "0x5f20920B62dCc4B43b194903d46d6B2aCc6d13EC";

  const QueryCurveUpgradeableBase = await ethers.getContractFactory(
    "QueryCurveUpgradeableBase"
  );

  const upgraded = await upgrades.upgradeProxy(
    baseQueryProxyAddress,
    QueryCurveUpgradeableBase
  );
  await upgraded.waitForDeployment();

  console.log("QueryCurveUpgradeableBase proxy upgraded:", baseQueryProxyAddress);
  console.log(
    "New implementation address:",
    await upgrades.erc1967.getImplementationAddress(baseQueryProxyAddress)
  );
  console.log(
    "Proxy admin address:",
    await upgrades.erc1967.getAdminAddress(baseQueryProxyAddress)
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Upgrade failed:", error);
    process.exit(1);
  });
