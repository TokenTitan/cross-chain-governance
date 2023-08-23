// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { GovernorCountingSimpleUpgradeable } from "./base/GovernorCountingSimpleUpgradeable.sol";
import { LayerZeroBase } from "./base/LayerZeroBase.sol";
import { TimersUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/utils/TimersUpgradeable.sol";
import { SafeCastUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";

contract CrossChainGovernance is GovernorCountingSimpleUpgradeable, LayerZeroBase {
    using TimersUpgradeable for TimersUpgradeable.BlockNumber;
    using SafeCastUpgradeable for uint256;

    uint256 private _quorum;
    uint256 private _votingDelay;
    uint256 private _votingPeriod;

    // maps proposal ID to the destination chain of proposal
    mapping(uint256 => uint256) private _proposalDestChains;

    function initialize(
        string memory _name,
        address _lzEndpoint,
        uint16 _chainId,
        uint256 _quorumNumber,
        uint256 _votingDelayTime,
        uint256 _votingDuration
    ) external initializer {
        require(_votingDuration > 0, "Invalid Voting Duration");
        require(_quorumNumber > 1, "Quorum should be greater than 1");

        _quorum = _quorumNumber;
        _votingDelay = _votingDelayTime;
        _votingPeriod = _votingDuration;
        __Ownable_init();
        __Governor_init(_name);
        __crossChainInit(_lzEndpoint, _chainId);
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
        uint16 targetChain,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256) {
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
        uint16 targetChain,
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
            _lzSend(
                targetChain,
                abi.encode(targetChain, targets, values, calldatas, descriptionHash),
                payable(msg.sender),
                address(0x0),
                bytes(""),
                msg.value
            );
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
        uint16 targetChain,
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
        // Let default vote weight be 1
        return 1;
    }

    function quorum(uint256 /* blockNumber */) public view override returns (uint256) {
        return _quorum;
    }

    function votingDelay() public view override returns (uint256) {
        return _votingDelay;
    }

    function votingPeriod() public view override returns (uint256) {
        return _votingPeriod;
    }

    function _processRecieve(bytes memory _payload) internal override {
        (
            uint16 targetChain,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = abi.decode(
                _payload,
                (uint16, address[], uint256[], bytes[], bytes32)
            );
        require(targetChain == chainId, "Invalid Request");

        uint256 proposalId = hashProposal(targetChain, targets, values, calldatas, descriptionHash);
        _beforeExecute(proposalId, targets, values, calldatas, descriptionHash);
        _execute(proposalId, targets, values, calldatas, descriptionHash);
        _afterExecute(proposalId, targets, values, calldatas, descriptionHash);
    }
}
