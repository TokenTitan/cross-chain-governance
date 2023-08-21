// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { GovernorCountingSimpleUpgradeable } from "./base/GovernorCountingSimpleUpgradeable.sol";
import { HyperlaneBase } from "./base/HyperlaneBase.sol";
import { TimersUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/utils/TimersUpgradeable.sol";
import { SafeCastUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";

contract CrossChainGovernance is GovernorCountingSimpleUpgradeable, HyperlaneBase {
    using TimersUpgradeable for TimersUpgradeable.BlockNumber;
    using SafeCastUpgradeable for uint256;

    // maps proposal ID to the destination chain of proposal
    mapping(uint256 => uint256) private _proposalDestChains;

    function initialize(
        string memory _name,
        address _mailbox,
        uint32 _chainId,
        uint32[2] memory _dstChainIds
    ) external initializer {
        __Ownable_init();
        __Governor_init(_name);
        __hyperlaneInit(_mailbox, _chainId, _dstChainIds);
    }

    /**
     * @dev See {IGovernor-propose}.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256) {
        return propose(chainId, targets, values, calldatas, description);
    }

    function propose(
        uint32 targetChain,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(
            getVotes(_msgSender(), block.number - 1) >= proposalThreshold(),
            "Governor: proposer votes below proposal threshold"
        );

        uint256 proposalId = hashProposal(targetChain, targets, values, calldatas, keccak256(bytes(description)));
        _proposalDestChains[proposalId] = targetChain;

        require(targets.length == values.length, "Governor: invalid proposal length");
        require(targets.length == calldatas.length, "Governor: invalid proposal length");
        require(targets.length > 0, "Governor: empty proposal");

        ProposalCore storage proposal = _proposals[proposalId];
        require(proposal.voteStart.isUnset(), "Governor: proposal already exists");

        uint64 snapshot = block.number.toUint64() + votingDelay().toUint64();
        uint64 deadline = snapshot + votingPeriod().toUint64();

        proposal.voteStart.setDeadline(snapshot);
        proposal.voteEnd.setDeadline(deadline);

        emit ProposalCreated(
            proposalId,
            _msgSender(),
            targets,
            values,
            new string[](targets.length),
            calldatas,
            snapshot,
            deadline,
            description
        );

        return proposalId;
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override returns (uint256) {
        return execute(chainId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev See {IGovernor-execute}.
     */
    function execute(
        uint32 targetChain,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable returns (uint256) {
        uint256 proposalId = hashProposal(targetChain, targets, values, calldatas, descriptionHash);

        ProposalState status = state(proposalId);
        require(
            status == ProposalState.Succeeded || status == ProposalState.Queued,
            "Governor: proposal not successful"
        );
        _proposals[proposalId].executed = true;

        emit ProposalExecuted(proposalId);

        if (targetChain == chainId) {
            _beforeExecute(proposalId, targets, values, calldatas, descriptionHash);
            _execute(proposalId, targets, values, calldatas, descriptionHash);
            _afterExecute(proposalId, targets, values, calldatas, descriptionHash);
        } else {
            _hlExecute(targetChain, targets, values, calldatas, descriptionHash);
        }

        return proposalId;
    }

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public view virtual override returns (uint256) {
        return hashProposal(chainId, targets, values, calldatas, descriptionHash);
    }

    function hashProposal(
        uint32 targetChain,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(targetChain, targets, values, calldatas, descriptionHash)));
    }

    /**
     * @dev Get the voting weight of `account` at a specific `blockNumber`, for a vote as described by `params`.
     */
    function _getVotes(
        address /* account */,
        uint256 /* blockNumber */,
        bytes memory /* params */
    ) internal pure override returns (uint256) {
        // TODO: to be implemented
        return 0;
    }

    function quorum(uint256 blockNumber) public view override returns (uint256) {

    }

    function votingDelay() public view override returns (uint256) {

    }

    function votingPeriod() public view override returns (uint256) {

    }

    function _processRecieve(bytes memory _payload) internal override {
        (
            uint32 targetChain,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = abi.decode(
                _payload,
                (uint32, address[], uint256[], bytes[], bytes32)
            );
        require(targetChain == chainId, "Invalid Request");

        uint256 proposalId = hashProposal(targetChain, targets, values, calldatas, descriptionHash);
        _beforeExecute(proposalId, targets, values, calldatas, descriptionHash);
        _execute(proposalId, targets, values, calldatas, descriptionHash);
        _afterExecute(proposalId, targets, values, calldatas, descriptionHash);
    }
}
