const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploy all required libraries first
  console.log("Deploying libraries...");

  const QueryUniv3TicksSuperCompact = await ethers.getContractFactory("QueryUniv3TicksSuperCompact");
  const queryUniv3 = await QueryUniv3TicksSuperCompact.deploy();
  await queryUniv3.deployed();
  console.log("QueryUniv3TicksSuperCompact deployed at:", queryUniv3.address);

  const QueryAlgebraTicksSuperCompact = await ethers.getContractFactory("QueryAlgebraTicksSuperCompact");
  const queryAlgebra = await QueryAlgebraTicksSuperCompact.deploy();
  await queryAlgebra.deployed();
  console.log("QueryAlgebraTicksSuperCompact deployed at:", queryAlgebra.address);

  const QueryHorizonTicksSuperCompact = await ethers.getContractFactory("QueryHorizonTicksSuperCompact");
  const queryHorizon = await QueryHorizonTicksSuperCompact.deploy();
  await queryHorizon.deployed();
  console.log("QueryHorizonTicksSuperCompact deployed at:", queryHorizon.address);

  const QueryIzumiSuperCompact = await ethers.getContractFactory("QueryIzumiSuperCompact");
  const queryIzumi = await QueryIzumiSuperCompact.deploy();
  await queryIzumi.deployed();
  console.log("QueryIzumiSuperCompact deployed at:", queryIzumi.address);

  const QueryUniv4TicksSuperCompact = await ethers.getContractFactory("QueryUniv4TicksSuperCompact");
  const queryUniv4 = await QueryUniv4TicksSuperCompact.deploy();
  await queryUniv4.deployed();
  console.log("QueryUniv4TicksSuperCompact deployed at:", queryUniv4.address);

  const QueryZoraTicksSuperCompact = await ethers.getContractFactory("QueryZoraTicksSuperCompact");
  const queryZora = await QueryZoraTicksSuperCompact.deploy();
  await queryZora.deployed();
  console.log("QueryZoraTicksSuperCompact deployed at:", queryZora.address);

  const QueryPancakeInfinityLBReserveSuperCompact = await ethers.getContractFactory("QueryPancakeInfinityLBReserveSuperCompact");
  const queryPancake = await QueryPancakeInfinityLBReserveSuperCompact.deploy();
  await queryPancake.deployed();
  console.log("QueryPancakeInfinityLBReserveSuperCompact deployed at:", queryPancake.address);

  const QueryCurveSuperCompact = await ethers.getContractFactory("QueryCurveSuperCompact");
  const queryCurve = await QueryCurveSuperCompact.deploy();
  await queryCurve.deployed();
  console.log("QueryCurveSuperCompact deployed at:", queryCurve.address);

  // Deploy QueryData with library links
  console.log("\nDeploying QueryData with library links...");
  const QueryData = await ethers.getContractFactory("QueryData", {
    libraries: {
      "src/extLib/QueryUniv3TicksSuperCompact.sol:QueryUniv3TicksSuperCompact": queryUniv3.address,
      "src/extLib/QueryAlgebraTicksSuperCompact.sol:QueryAlgebraTicksSuperCompact": queryAlgebra.address,
      "src/extLib/QueryHorizonTicksSuperCompact.sol:QueryHorizonTicksSuperCompact": queryHorizon.address,
      "src/extLib/QueryIzumiSuperCompact.sol:QueryIzumiSuperCompact": queryIzumi.address,
      "src/extLib/QueryUniv4TicksSuperCompact.sol:QueryUniv4TicksSuperCompact": queryUniv4.address,
      "src/extLib/QueryZoraTicksSuperCompact.sol:QueryZoraTicksSuperCompact": queryZora.address,
      "src/extLib/QueryPancakeInfinityLBReserveSuperCompact.sol:QueryPancakeInfinityLBReserveSuperCompact": queryPancake.address,
      "src/extLib/QueryCurveSuperCompact.sol:QueryCurveSuperCompact": queryCurve.address,
    }
  });

  const proxy = await upgrades.deployProxy(
    QueryData, []
  );

  await proxy.deployed();

  console.log("\n=== Deployment Summary ===");
  console.log("Proxy address:", proxy.address);
  console.log("Implementation address:", await upgrades.erc1967.getImplementationAddress(proxy.address));
  console.log("Admin address:", await upgrades.erc1967.getAdminAddress(proxy.address));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });