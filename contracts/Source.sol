// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./lzApp/NonblockingLzApp.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract Source is NonblockingLzApp {
    using SafeMath for uint256;

    // Address of Destination contract where all the money will be sent
    address public destination;
    // Whether a limit is set for users
    bool public hasUserLimit;
    // Chain id of Destination Chain
    uint16 public dstChainId;
    // The token being staked -- CAKE
    IERC20 public stakedToken;

    /// @notice Constructor
    /// @param _lzEndpoint: LayerZero Endpoint
    /// @param _dstChainId: Chain Id of the destination address
    /// @param _stakedToken: The token being staked
    constructor(
        address _lzEndpoint,
        uint16 _dstChainId,
        address _stakedToken
    ) NonblockingLzApp(_lzEndpoint) {
        dstChainId = _dstChainId;
        stakedToken = IERC20(_stakedToken);
    }

    /// @notice function to deposit stakedToken remotely
    /// @param _amount: the amount of tokens being deposited
    function omniDeposit(uint256 _amount) public payable {
        require(msg.value > 0, "stargate requires fee to pay crosschain message");

        stakedToken.transferFrom(msg.sender, address(this), _amount);
        
        bytes memory data = abi.encode("deposit", msg.sender, _amount);
        
        _lzSend(
            dstChainId, 
            data, 
            payable(msg.sender), 
            address(0x0), 
            bytes(""),
            msg.value
        );
    }

    /// @notice function to withdraw stakedToken remotely
    /// @param _amount: the amount of tokens being withdrawn
    function omniWithdraw(uint256 _amount) public payable {
        require(msg.value > 0, "stargate requires fee to pay crosschain message");
        
        bytes memory data = abi.encode("withdraw", msg.sender, _amount);
        
        _lzSend(
            dstChainId, 
            data, 
            payable(msg.sender), 
            address(0x0), 
            bytes(""),
            msg.value
        );
    }

    /// @notice function to claim reward remotely
    function omniClaim() public payable {
        require(msg.value > 0, "stargate requires fee to pay crosschain message");
        
        bytes memory data = abi.encode("claim", msg.sender, 0);
        
        _lzSend(
            dstChainId, 
            data, 
            payable(msg.sender), 
            address(0x0), 
            bytes(""),
            msg.value
        );
    }

    /// @notice LayerZero Function For Receive Messages From Destination Address
    /// @param _srcChainId: chain id of the sending chain
    /// @param _srcAddress: the sending address
    /// @param _nonce: nonce of the message
    /// @param _payload: the message
    function _nonblockingLzReceive(
        uint16 _srcChainId, 
        bytes memory _srcAddress, 
        uint64 _nonce, 
        bytes memory _payload
    ) internal override {
        address srcAddress;
        assembly {
            srcAddress := mload(add(_srcAddress, 20))
        }

        // message can be only sent by `destination` contract
        require(srcAddress == destination, "not sent by destination contract");

        /// @param message: the message
        /// @param userAddress: address of the user
        /// @param amount: amount of tokens being withdrawn or refunded
        (string memory message, address userAddress, uint256 amount) = abi.decode(_payload, (string, address, uint256));

        if (keccak256(bytes(message)) == keccak256(bytes("deposit_fail"))) {
            stakedToken.transfer(userAddress, amount);
        } else if (keccak256(bytes(message)) == keccak256(bytes("withdraw"))) {
            stakedToken.transfer(userAddress, amount);
        }
    }
}