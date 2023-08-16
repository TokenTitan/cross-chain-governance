// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OwnableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

abstract contract MultilayerBase is OwnableUpgradeable {
    address public chainEndpoint;
    uint16[2] public dstChainIds;

    mapping(uint16 => bytes) public trustedRemoteLookup;

    event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress);

    error InvalidEvent();

    /**
     * @dev Sets the values for {_chainEndpoint} and {dstChainIds}.
     * @param _chainEndpoint communication endpoint on this chain
     * @param _dstChainIds destination chain ids
     */
    function __multilayerInit(
        address _chainEndpoint,
        uint16[2] memory _dstChainIds
    ) internal initializer (
    ) {
        chainEndpoint = _chainEndpoint;
        uint256 noOfChains = _dstChainIds.length;

        for(uint256 _index = 0; _index < noOfChains; _index++) {
            dstChainIds[_index] = _dstChainIds[_index]; // TODO: can try a more optimal way
        }
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

    /**
     * @dev abstract function for the importing contract to implement functionality accordingly
     * @param _payload message added to the source transaction
     */
    function _processRecieve(bytes memory _payload) internal virtual;
}