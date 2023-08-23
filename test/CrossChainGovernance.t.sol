// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/console.sol";

import { Test } from "forge-std/Test.sol";
import { CrossChainGovernance } from "../src/CrossChainGovernance.sol";
import { ERC20Mock } from "src/mocks/ERC20Mock.sol";
import { LZEndpointMock } from "src/mocks/LZEndpointMock.sol";

import { IGovernorUpgradeable } from "src/interfaces/IGovernorUpgradeable.sol";

// deployment scripts
import { ProxyAdminScript } from "script/00_deployProxyAdmin.s.sol";
import { CrossChainGovernanceScript } from "script/01_deployCrossChainGovernance.s.sol";

contract CrossChainGovernanceTest is Test {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    address public constant MOCK_USER_1 = address(1);
    address public constant MOCK_USER_2 = address(2);
    address public constant MOCK_USER_3 = address(3);

    uint16 public constant CHAIN_ID_1 = 123;
    uint16 public constant CHAIN_ID_2 = 456;

    CrossChainGovernance public crossChainGovernance1;
    CrossChainGovernance public crossChainGovernance2;

    LZEndpointMock public lzEndPoint1;
    LZEndpointMock public lzEndPoint2;

    ERC20Mock public eRC20Mock;

    address[] private _targets;
    uint256[] private _values;
    bytes[] private _calldatas;

    function setUp() public {
        ProxyAdminScript proxyAdminScript = new ProxyAdminScript();
        address proxyAdminAddr = proxyAdminScript.deployForTest();

        lzEndPoint1 = new LZEndpointMock(CHAIN_ID_1);
        console.log("Deployed lz endpoint for chain 1 at: ", address(lzEndPoint1));
        lzEndPoint2 = new LZEndpointMock(CHAIN_ID_2);
        console.log("Deployed lz endpoint for chain 2 at: ", address(lzEndPoint2));

        CrossChainGovernanceScript crossChainGovernanceScript = new CrossChainGovernanceScript();

        crossChainGovernance1 = CrossChainGovernance(
            payable(crossChainGovernanceScript.deployForTest(
                proxyAdminAddr,
                address(lzEndPoint1),
                CHAIN_ID_1
            ))
        );

        crossChainGovernance2 = CrossChainGovernance(
            payable(crossChainGovernanceScript.deployForTest(
                proxyAdminAddr,
                address(lzEndPoint2),
                CHAIN_ID_2
            ))
        );

        // internal bookkeeping for endpoints (not part of a real deploy, just for this test)
        console.log("Setting up endpoints...");
        lzEndPoint1.setDestLzEndpoint(address(crossChainGovernance2), address(lzEndPoint2));
        lzEndPoint2.setDestLzEndpoint(address(crossChainGovernance1), address(lzEndPoint1));
        console.log("Done.");

        // needs to be set after deployment
        console.log("Setting up trusted remote addresses...");
        crossChainGovernance1.setTrustedRemoteAddress(CHAIN_ID_2, abi.encodePacked(address(crossChainGovernance2)));
        crossChainGovernance2.setTrustedRemoteAddress(CHAIN_ID_1, abi.encodePacked(address(crossChainGovernance1)));
        console.log("Done.");

        // deploying mock ERC20 contract
        eRC20Mock = new ERC20Mock("Mock ERC20", "MERC20");
    }

    function testProposedMintAcrossChain() public {
        vm.deal(address(crossChainGovernance1), 1 ether);
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", MOCK_USER_1, 10e18);
        _targets.push(address(eRC20Mock));
        _values.push(uint256(1));
        _calldatas.push(data);
        uint256 proposalId = crossChainGovernance1.propose(
            CHAIN_ID_2,
            _targets,
            _values,
            _calldatas,
            ""
        );
        vm.roll(block.number + 1); // voting starts from the next block
        vm.prank(MOCK_USER_1);
        crossChainGovernance1.castVote(proposalId, uint8(VoteType.For));
        vm.prank(MOCK_USER_2);
        crossChainGovernance1.castVote(proposalId, uint8(VoteType.For));

        eRC20Mock.setGovernor(address(crossChainGovernance2));
        assertTrue(eRC20Mock.totalSupply() == 0);

        vm.roll(block.number + 3); // excute after voting deadline
        crossChainGovernance1.execute{value: 0.1 ether}(
            CHAIN_ID_2,
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(""))
        );
    
        assertTrue(eRC20Mock.totalSupply() == 10e18);
        assertTrue(eRC20Mock.balanceOf(MOCK_USER_1) == 10e18);
    }
}
