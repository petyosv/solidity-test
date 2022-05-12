//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Store Contract.
 * @author Petyo Stoyanov.
 * @notice Create simple store with products.
 * @dev This is a test project.
 */
contract Store {

  address private owner;

  mapping (string => uint256)   productIndex;
  mapping (address => uint256)  buyerIndex;

  Product[]     products;
  Buyer[]       buyers;
  Transaction[] transactions;

  struct Product {
    uint256 id;
    string name;
    uint256 quantity;
    address[] buyers;
  }

  struct Buyer {
    address id;
    uint256[] transactions;
  }

  struct Transaction {
    uint256 productId;
    int256 quantity;
    uint256 blockNumber;
    address account;
  }

  /**
   * @dev Check if caller is the owner.
   */
  modifier isOwner() {
    require(msg.sender == owner, "Caller is not the owner");
    _;
  }

  /**
   * @dev Validate that product with given name exists.
   */
  modifier productExists(string memory _name) {
    require(checkForProductByName(_name), "Product does not exists");
    _;
  }

  /**
   * @dev Validate that product with given name doesn't exists.
   */
  modifier productDoesNotExists(string memory _name) {
    require(!checkForProductByName(_name), "Product already exists");
    _;
  }

  /**
   * @dev Validate that product exists and have the required quantity.
   */
  modifier isAvailable(uint256 _id, uint256 _quantity) {
    require(checkForProductById(_id), "Product does not exists");
    require(products[_id].quantity >= _quantity, "Not enough in stock");
    _;
  }

  /**
   * @dev Validate that account hasn't bought the product.
   */
  modifier hasProduct(uint256 _id) {
    bool _found = false;

    for (uint256 _index; _index < products[_id].buyers.length; _index++) {
      if (products[_id].buyers[_index] == msg.sender) {
        _found = true;
      }
    }

    require(!_found, "The product already has been bought");
    _;
  }

  /**
   * @dev Validate that account transaction and can be returned.
   */
  modifier canReturn(uint256 _index) {
    uint256 _buyerIndex = getBuyerIndex(msg.sender);
    require(
      buyers[_buyerIndex].transactions.length > _index &&
      transactions.length > buyers[_buyerIndex].transactions[_index],
      "Transaction not found"
    );
    uint256 _transactionIndex = buyers[_buyerIndex].transactions[_index];
    require(
      transactions[_transactionIndex].blockNumber + 10 > block.number,
      "The product can't be return"
    );
    _;
  }

  /**
   * @dev Set the owner.
   */
  constructor() {
    owner = msg.sender;
  }

  /**
   * @dev Check if product with given name exists.
   *
   * @param _name Name of the product.
   *
   * @return True if the product exists.
   */
  function checkForProductByName(string memory _name) private view returns(bool) {
    uint256 _index = productIndex[_name];
    return (
      products.length > _index &&
      keccak256(abi.encode(products[_index].name)) == keccak256(abi.encode(_name))
    );
  }

  /**
   * @dev Check if product with given name exists.
   *
   * @param _id ID/Index of the product.
   *
   * @return True if the product exists.
   */
  function checkForProductById(uint256 _id) private view returns(bool) {
    return (
      products.length > _id &&
      products[_id].id == _id
    );
  }

  /**
   * @notice Add product to the store.
   *
   * @param _name Name of the product.
   * @param _quantity Quantity of the product.
   */
  function addProduct(
    string memory _name,
    uint256 _quantity
  ) public isOwner() productDoesNotExists(_name) {

    uint256 _id = products.length;
    address[] memory _buyers;

    Product memory _product = Product({
      id: _id,
      name: _name,
      quantity: _quantity,
      buyers: _buyers
    });

    products.push(_product);
    productIndex[_name] = _id;
  }

  /**
   * @notice Add quantity to a product.
   *
   * @param _name Name of the product.
   * @param _quantity Quantity of the product.
   */
  function addQuantity (
    string memory _name,
    uint256 _quantity
  ) public isOwner() productExists(_name) {

    uint256 _index = productIndex[_name];

    products[_index].quantity += _quantity;
  }

  /**
   * @notice Retrieve all products.
   *
   * @return The list of products.
   */
  function getProducts() public view returns(Product[] memory) {
    Product[] memory _products = new Product[](products.length);

    for (uint256 _index; _index < products.length; _index++) {
      _products[_index] = products[_index];
    }

    return _products;
  }

  /**
   * @notice Retrieve a product.
   *
   * @param _id The product ID.
   *
   * @return Product.
   */
  function getProduct(uint256 _id) public view returns(Product memory) {
    return products[_id];
  }

  /**
   * @notice Buy a product.
   *
   * @param _productId The product id/index.
   * @param _quantity The quantity user wants to buy.
   */
  function buy (
    uint256 _productId,
    uint256 _quantity
  ) public isAvailable(_productId, _quantity) hasProduct(_productId) {
    products[_productId].quantity -= _quantity;
    products[_productId].buyers.push(msg.sender);

    uint256 _transactionIndex = transactions.length;
    transactions.push( Transaction({
      productId: _productId,
      quantity: int256(_quantity),
      blockNumber: block.number,
      account: msg.sender
    }) );

    uint256 _index = getBuyerIndex(msg.sender);
    buyers[_index].transactions.push(_transactionIndex);
  }

  /**
   * @notice Return product by transaction number.
   *
   * @param _index The transaction number of the current account.
   */
  function returnByBuyerTransaction (
    uint256 _index
  ) public canReturn(_index) {
    uint256 _buyerIndex = getBuyerIndex(msg.sender);
    uint256 _transactionIndex = buyers[_buyerIndex].transactions[_index];

    transactions.push( Transaction({
      productId: transactions[_transactionIndex].productId,
      quantity: transactions[_transactionIndex].quantity * -1,
      blockNumber: block.number,
      account: msg.sender
    }) );

    products[transactions[_transactionIndex].productId].quantity += uint256(transactions[_transactionIndex].quantity);

    for (uint256 _i; _i < buyers[_buyerIndex].transactions.length - 1; _i++) {
      if (_i >= _index) {
        buyers[_buyerIndex].transactions[_i] = buyers[_buyerIndex].transactions[_i+1];
      }
    }
    buyers[_buyerIndex].transactions.pop();
  }

  /**
   * @notice Return product by product id.
   *
   * @param _productId The product id.
   */
  function returnByProductId (
    uint256 _productId
  ) public {
    uint256 _buyerIndex = getBuyerIndex(msg.sender);
    uint256[] memory _transactions = buyers[_buyerIndex].transactions;
    uint256 _count = _transactions.length;

    for (uint256 _index; _index < _count; _index++) {
      if (transactions[_transactions[_index]].productId == _productId) {
        returnByBuyerTransaction(_index);
        break;
      }
    }
  }

  /**
   * @notice Return product from last transaction.
   */
  function returnLastTransaction () public {
    uint256 _buyerIndex = getBuyerIndex(msg.sender);
    require(buyers[_buyerIndex].transactions.length > 0);
    uint256 _transactionIndex = buyers[_buyerIndex].transactions.length - 1;
    returnByBuyerTransaction(_transactionIndex);
  }

  /**
   * @dev Get existing index of the buyer or create new one.
   *
   * @param _id The address of the buyer.
   *
   * @return The index of the buyer.
   */
  function getBuyerIndex(
    address _id
  ) private returns(uint256) {
    uint256 _index = buyerIndex[_id];
    if (
      buyers.length > _index &&
      buyers[_index].id == _id
    ) {
      return _index;
    }

    uint256[] memory _transactions;
    Buyer memory _buyer = Buyer({
      id: _id,
      transactions: _transactions
    });

    _index = buyers.length;
    buyers.push(_buyer);

    return _index;
  }

  /**
   * @notice Retrieve a buyer by address.
   *
   * @param _id The address of the buyer.
   *
   * @return The buyer.
   */
  function getBuyer (
    address _id
  ) public view returns(Buyer memory) {
    uint256 _index = buyerIndex[_id];
    require (
      buyers.length > _index &&
      buyers[_index].id == _id
    );

    return buyers[_index];
  }
}
