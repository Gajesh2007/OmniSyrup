// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./lzApp/NonblockingLzApp.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract Source is NonblockingLzApp {
    using SafeMath for uint256;

    uint256 constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // Address of Destination contract where all the money will be sent
    address public destination;
    // Price for each NFT
    uint256 public constant price = 50000000000000000; // 0.05 ETH
    // Maximum amount of NFTs mintable in one transaction
    uint public constant maxPurchase = 5;
    // Chain id of Destination Chain
    uint16 public dstChainId;
    // WETH
    IERC20 public weth;

    constructor(
        address _lzEndpoint,
        uint16 _dstChainId,
        address _weth
    ) NonblockingLzApp(_lzEndpoint) {
        dstChainId = _dstChainId;
        weth = WETH(_weth);
    }

    function omniMint(uint256 _amount) public payable {
        require(_amount > 0 && _amount <= maxPurchase, "Can only mint 5 NFTs at a time");
        uint256 cost = _amount.mul(price);
        require(msg.value > 0, "stargate requires fee to pay crosschain message");

        weth.transferFrom(msg.sender, address(this), cost);
        weth.withdraw(weth.balanceOf(address(this)));
        
        bytes memory data = abi.encode(msg.sender, _amount);
        
        _lzSend(
            dstChainId, 
            data, 
            payable(msg.sender), 
            address(0x0), 
            bytes(""),
            msg.value
        );
    }


    function omniMintNative(uint256 _amount, uint256 _fee) public payable {
        require(_amount > 0 && _amount <= maxPurchase, "Can only mint 5 NFTs at a time");
        uint256 cost = _amount.mul(price);
        require(msg.value > (cost + _fee), "eth is not enough");
        
        bytes memory data = abi.encode(msg.sender, _amount);
        
        _lzSend(
            dstChainId, 
            data, 
            payable(msg.sender), 
            address(0x0), 
            bytes(""),
            _fee
        );
    }

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

        require(srcAddress == destination, "not sent by destination contract");

        (address _user, uint256 _amountToSend) = abi.decode(_payload, (address, uint256));

        payable(_user).transfer(_amountToSend);
    }

    receive() external payable {}
}