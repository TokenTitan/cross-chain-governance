// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// Package Imports
import { OwnableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

// Interfaces
import { ILayerZeroReceiverUpgradeable } from "../interfaces/ILayerZeroReceiverUpgradeable.sol";
import { ILayerZeroEndpointUpgradeable } from "../interfaces/ILayerZeroEndpointUpgradeable.sol";

abstract contract LayerZeroBase is OwnableUpgradeable, ILayerZeroReceiverUpgradeable {
    uint256 constant public DEFAULT_PAYLOAD_SIZE_LIMIT = 10000;

    address public chainEndpoint;
    uint16 public chainId;
    uint16[2] public dstChainIds;

    mapping(uint16 => bytes) public trustedRemoteLookup;
    mapping(uint16 => uint256) public payloadSizeLimitLookup;

    event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress);

    error InvalidEvent();

    /**
     * @dev Sets the values for {chainEndpoint} and {chainId}.
     * @param _chainEndpoint communication endpoint on this chain
     * @param _chainId of the deployment network
     */
    function __crossChainInit(
        address _chainEndpoint,
        uint16 _chainId
    ) internal initializer (
    ) {
        chainId = _chainId;
        chainEndpoint = _chainEndpoint;
    }

    /**
     * @notice function executed by the layer zero endpoint on this chain, also checks for its validity
     * @param _srcChainId id of the source chain
     * @param _srcAddress address of the source chain contract
     * param(unused) _nonce of the transaction
     * @param _payload message added to the source transaction
     */
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 /*_nonce*/, bytes calldata _payload) public virtual override {
        // lzReceive must be called by the endpoint for security
        require(_msgSender() == chainEndpoint, "LzApp: invalid endpoint caller"); // TODO: use revert instead

        bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
        // if will still block the message pathway from (srcChainId, srcAddress). should not receive message from untrusted remote.
        require(_srcAddress.length == trustedRemote.length && trustedRemote.length > 0 && keccak256(_srcAddress) == keccak256(trustedRemote), "LzApp: invalid source sending contract");
        _processRecieve(_payload);
    }

    /**
     * @notice if the size is 0, it means default size limit
     * @dev setter for payload size limit
     * @param _dstChainId id of the chain for which we want to set
     * @param _size max sie of the payload
     */
    function setPayloadSizeLimit(uint16 _dstChainId, uint _size) external onlyOwner {
        payloadSizeLimitLookup[_dstChainId] = _size;
    }

    /**
     * @dev authorise remote chain address corresponding to each chain Id
     * @param _remoteChainId chain id of the target chain
     * @param _remoteAddress address of the contract on target chain
     */
    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external onlyOwner {
        trustedRemoteLookup[_remoteChainId] = abi.encodePacked(_remoteAddress, address(this));
        emit SetTrustedRemoteAddress(_remoteChainId, _remoteAddress);
    }

    // GETTERS

    function getLayerZeroEndpoint() external view returns(address) {
        return chainEndpoint;
    }

    // INTERNAL

    /**
    // @notice send a LayerZero message to the specified address at a LayerZero endpoint.
    // @param _payload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    // @param _zroPaymentAddress - the address of the ZRO token holder who would pay for the transaction
    // @param _adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
     */
    function _lzSend(uint16 _dstChainId, bytes memory _payload, address payable _refundAddress, address _zroPaymentAddress, bytes memory _adapterParams, uint _nativeFee) internal virtual {
        bytes memory trustedRemote = trustedRemoteLookup[_dstChainId];
        require(trustedRemote.length != 0, "LzApp: destination chain is not a trusted source");
        _checkPayloadSize(_dstChainId, _payload.length);
        ILayerZeroEndpointUpgradeable(chainEndpoint)
            .send{value: _nativeFee}(
                _dstChainId,
                trustedRemote,
                _payload,
                _refundAddress,
                _zroPaymentAddress,
                _adapterParams
            );
    }

    function _checkPayloadSize(uint16 _dstChainId, uint _payloadSize) internal view virtual {
        uint payloadSizeLimit = payloadSizeLimitLookup[_dstChainId];
        if (payloadSizeLimit == 0) { // use default if not set
            payloadSizeLimit = DEFAULT_PAYLOAD_SIZE_LIMIT;
        }
        require(_payloadSize <= payloadSizeLimit, "LzApp: payload size is too large");
    }

    /**
     * @dev abstract function for the importing contract to implement functionality accordingly
     * @param _payload message added to the source transaction
     */
    function _processRecieve(bytes memory _payload) internal virtual;
}
