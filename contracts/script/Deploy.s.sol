// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {CimonRegistry} from "../src/CimonRegistry.sol";
import {CimonPay} from "../src/CimonPay.sol";
import {ICimonRegistry} from "../src/interfaces/ICimonRegistry.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

/// @notice Deploys CIMON to the QDay Aevum Testnet (chain id 44005).
///
///         forge script script/Deploy.s.sol:Deploy \
///           --rpc-url https://rpc-test.qday.info --broadcast --legacy
///
///         Environment variables:
///           PRIVATE_KEY      deployer key (required); becomes registry owner unless REGISTRY_OWNER set
///           REGISTRY_OWNER   optional owner for the registry (defaults to the deployer)
///           TUSD8_ADDRESS    optional override of the settlement token
///           ATTESTOR         optional extra attestor that can verify businesses and flag addresses
///
///         Writes addresses to deployments/aevum-testnet.json for the frontend and README.
contract Deploy is Script {
    uint256 internal constant AEVUM_TESTNET_CHAIN_ID = 44005;
    address internal constant TUSD8 = 0x456569838f1d43009A91ebA4263147Afd7233483;

    function run() external returns (CimonRegistry registry, CimonPay pay) {
        require(block.chainid == AEVUM_TESTNET_CHAIN_ID, "Deploy: not on Aevum Testnet (44005)");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address registryOwner = vm.envOr("REGISTRY_OWNER", deployer);
        address token = vm.envOr("TUSD8_ADDRESS", TUSD8);
        address attestor = vm.envOr("ATTESTOR", address(0));

        require(token.code.length > 0, "Deploy: tUSD8 has no code at this address");

        vm.startBroadcast(deployerKey);

        // Deployer is the initial owner so it can wire up the recorder in the same script.
        registry = new CimonRegistry(deployer);
        pay = new CimonPay(IERC20(token), ICimonRegistry(address(registry)));
        registry.setRecorder(address(pay), true);
        if (attestor != address(0)) {
            registry.setAttestor(attestor, true);
        }
        if (registryOwner != deployer) {
            registry.transferOwnership(registryOwner); // new owner must call acceptOwnership()
        }

        vm.stopBroadcast();

        console2.log("CIMON deployed on Aevum Testnet");
        console2.log("  CimonRegistry:", address(registry));
        console2.log("  CimonPay:     ", address(pay));
        console2.log("  tUSD8:        ", token);
        console2.log("  owner:        ", deployer);
        if (registryOwner != deployer) {
            console2.log("  pending owner:", registryOwner);
        }

        string memory key = "cimon";
        vm.serializeUint(key, "chainId", block.chainid);
        vm.serializeAddress(key, "CimonRegistry", address(registry));
        vm.serializeAddress(key, "CimonPay", address(pay));
        vm.serializeAddress(key, "tUSD8", token);
        vm.serializeUint(key, "deployBlock", block.number);
        string memory json = vm.serializeAddress(key, "deployer", deployer);
        vm.writeJson(json, "./deployments/aevum-testnet.json");
    }
}
