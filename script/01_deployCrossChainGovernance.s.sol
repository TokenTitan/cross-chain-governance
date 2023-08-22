// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { CrossChainGovernance } from "../src/CrossChainGovernance.sol";
import { TransparentUpgradeableProxy } from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract CrossChainGovernanceScript is Script {
    string public deploymentNetwork;

    address public proxyAdminAddr;
    address public proxyAddr;
    address public lzEndpointAddr;

    uint16 public chainId;

    uint256 public quorum;
    uint256 public votingDelay;
    uint256 public votingPeriod;

    bool public forTest;

    function run() public {
        console.log("Deploying Cross Chain Governance");

        // take values from the env if it is not a test environment
        if (!forTest) {
            deploymentNetwork = vm.envString(
                "DEPLOYMENT_NETWORK"
            );

            if (bytes(deploymentNetwork).length == 0) {
                revert("Deployment network is not set in .env file");
            }
            if (
                bytes(
                    vm.envString(
                        string.concat("PROXY_ADMIN_ADDR_", deploymentNetwork)
                    )
                ).length == 0
            ) {
                revert("ProxyAdmin address is not set in .env file");
            }

            proxyAdminAddr = vm.envAddress(
                string.concat("PROXY_ADMIN_ADDR_", deploymentNetwork)
            );

            lzEndpointAddr = vm.envAddress(
                string.concat("LZ_ENDPOINT_", deploymentNetwork)
            );

            chainId = uint16(vm.envUint(
                string.concat("CHAIN_ID_", deploymentNetwork)
            ));
        }

        quorum = uint256(vm.envUint(
            string.concat("QUORUM")
        ));

        votingDelay = uint256(vm.envUint(
            string.concat("VOTING_DELAY")
        ));

        votingPeriod = uint256(vm.envUint(
            string.concat("VOTING_PERIOD")
        ));

        vm.startBroadcast();

        // deploy implementation contract
        address implementationAddr = address(new CrossChainGovernance());

        console.log(
            "Implementation contract deployed at",
            implementationAddr
        );

        // deploy proxy contract
        proxyAddr = address(
            new TransparentUpgradeableProxy(
                implementationAddr,
                proxyAdminAddr,
                abi.encodeWithSelector(
                    CrossChainGovernance(payable(address(0))).initialize.selector,
                    "CrossChainGovernance",
                    lzEndpointAddr,
                    chainId,
                    quorum,
                    votingDelay,
                    votingPeriod
                )
            )
        );

        console.log(
            "Cross Chain proxy deployed with Hyperlane at",
            proxyAddr
        );
        CrossChainGovernance(payable(proxyAddr)).transferOwnership(msg.sender);
        vm.stopBroadcast();
    }

    function deployForTest(
        address _proxyAdmin,
        address _lzEndpointAddr,
        uint16 _chainId
    ) public returns (address) {
        // set state parameters for test deployment
        forTest = true;
        proxyAdminAddr = _proxyAdmin;
        lzEndpointAddr = _lzEndpointAddr;
        chainId = _chainId;

        run();

        // reset state values
        forTest = false;
        proxyAdminAddr = address(0);
        lzEndpointAddr = address(0);
        chainId = 0;
        return proxyAddr;
    }
}
