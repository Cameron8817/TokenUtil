// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Coin.sol";
import "./NFT.sol";

contract LabrysVendor is Ownable, IERC721Receiver, PullPayment {
  LabrysCoin private coin;
  LabrysToken private token;

  uint256 public coinCost = 0.001 ether;
  uint256 public ratio = 90; // 10% fee for buy/sell

  struct Item {
    address owner;
    uint256 cost;
    bool available;
  }

  mapping(uint256 => Item) items;

  event NetItemAvailable(uint256 _tokenId, uint256 _cost);
  event ItemSelled(uint256 _tokenId, address buyer);
  event TokenInfoSet(address _coinAddr, address _tokenAddr);

  constructor() {}

  function setTokenInfo(address _coinAddr, address _tokenAddr)
    public
    onlyOwner
  {
    require(_coinAddr != address(0), "Coin address is zero");
    require(_tokenAddr != address(0), "Token address is zero");

    coin = LabrysCoin(_coinAddr);
    token = LabrysToken(_tokenAddr);

    emit TokenInfoSet(_coinAddr, _tokenAddr);
  }

  function buyCoin() public payable {
    uint256 coinAmount = msg.value / coinCost;
    coin.transfer(_msgSender(), coinAmount);
  }

  // Buy my token by selected token(ex. Tether)
  function buyToken(uint256 _tokenId) public {
    require(items[_tokenId].available, "Already selled");

    items[_tokenId].available = false;

    // receive coin form buyer
    bool success = coin.transferFrom(
      _msgSender(),
      address(this),
      items[_tokenId].cost
    );
    require(success, "Failed to receive coin from buyer");

    // Send token to buyer
    token.safeTransferFrom(address(this), _msgSender(), _tokenId);

    // send coin to seller
    success = coin.transfer(
      items[_tokenId].owner,
      (items[_tokenId].cost * ratio) / 100
    );
    require(success, "Failed to send coin to seller");

    // emit event
    emit ItemSelled(_tokenId, _msgSender());
  }

  // Sell token by selected token(ex. USDT)
  function sellToken(uint256 _tokenId, uint256 _cost) public {
    require(token.ownerOf(_tokenId) == _msgSender(), "Invalid ownership");
    require(_cost > 0, "Zero cost");

    // transfer token from seller to vendor
    token.safeTransferFrom(_msgSender(), address(this), _tokenId);

    // add to items
    items[_tokenId] = Item({
      owner: _msgSender(),
      cost: _cost,
      available: true
    });

    // emit event
    emit NetItemAvailable(_tokenId, _cost);
  }

  // @dev Overriden in order to make it onlyOwner function
  function withdrawPayments(address payable payee)
    public
    virtual
    override
    onlyOwner
  {
    super.withdrawPayments(payee);
  }

  // @dev Override
  function onERC721Received(
    address, //operator,
    address, //from,
    uint256, //tokenId,
    bytes calldata // data
  ) external pure override returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }
}
