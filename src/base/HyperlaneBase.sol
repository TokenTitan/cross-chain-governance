// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// Package Imports
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { MultilayerBase } from "./MultilayerBase.sol";

interface IMailbox {
    function localDomain() external view returns (uint32);

    function dispatch(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes calldata _messageBody
    ) external returns (bytes32);

    function process(bytes calldata _metadata, bytes calldata _message)
        external;

    function count() external view returns (uint32);

    function root() external view returns (bytes32);

    function latestCheckpoint() external view returns (bytes32, uint32);
}

abstract contract HyperlaneBase is MultilayerBase {
    uint256 private mintCost;

    event Executed(address indexed _from, bytes _value);

    error InsufficientFundsProvidedForMint();

    function __hyperlaneInit(
        address _mailbox,
        uint32 _chainId,
        uint32[2] memory _dstChainIds
    ) internal initializer {
        __multilayerInit(_mailbox, _chainId, _dstChainIds);
    }

    // To receive the message from Hyperlane
    function handle(
        uint32,
        bytes32,
        bytes calldata _payload
    ) public {
        _processRecieve(_payload);
    }

    /**
     * @dev to send message to Hyperlane
     * @param targetChain the chain id of destination
     * @param targets address of the target contracts
     * @param values to be used when executing proposal
     * @param calldatas to be executed according to the proposal
     * @param descriptionHash additional data
    */
    function _hlExecute(
        uint32 targetChain,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal {
        bytes memory _message = abi.encode(targetChain, targets, values, calldatas, descriptionHash);

        bytes memory _path = trustedRemoteLookup[targetChain];
        address _recipient;
        assembly {
            _recipient := mload(add(_path, 20))
        }
        bytes32 addressInBytes32 = _addressToBytes32(_recipient);
        IMailbox(chainEndpoint)
            .dispatch(
                targetChain,
                addressInBytes32,
                _message
            );
    }

    function _addressToBytes32(address _addr) private pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}