// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract ProxyAdminScript is Script {
    bool private forTest;
    address private proxyAdmin;

    function run() public {
        vm.startBroadcast();
        proxyAdmin = address(new ProxyAdmin());
        console.log("ProxyAdmin deployed at", address(proxyAdmin));
        vm.stopBroadcast();
    }

    function deployForTest() public returns (address testAddr) {
        forTest = true;
        run();
        forTest = false;
        testAddr = address(proxyAdmin);
        proxyAdmin = address(0);
    }
}
