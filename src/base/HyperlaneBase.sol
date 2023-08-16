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
        uint256 _mintCost,
        uint16[2] memory _dstChainIds
    ) internal initializer {
        __multilayerInit(_mailbox, _dstChainIds);
        mintCost = _mintCost;
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
     * @param _from address of the token sender
     * @param _to address of the token reciever
     * @param _amount the number of tokens being transferred
    */
    function _hlSend(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if(msg.value < mintCost) {
            revert InsufficientFundsProvidedForMint();
        }
        bytes memory _message = abi.encode(_from, _to, _amount);
        uint256 noOfChains = dstChainIds.length;
        uint16[2] memory dstChainIds = dstChainIds;
        for(uint256 _index = 0; _index < noOfChains; _index++) {
            uint16 _destinationDomain = dstChainIds[_index];
            bytes memory _path = trustedRemoteLookup[_destinationDomain];
            address _recipient;
            assembly {
                _recipient := mload(add(_path, 20))
            }
            bytes32 addressInBytes32 = _addressToBytes32(_recipient);
            IMailbox(chainEndpoint)
                .dispatch(
                    uint32(_destinationDomain),
                    addressInBytes32,
                    _message
                );
        }
    }

    function _addressToBytes32(address _addr) private pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}