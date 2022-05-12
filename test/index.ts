import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";

// eslint-disable-next-line node/no-missing-import
import { Store as StoreType } from "../typechain";

let Store;
let store: StoreType;
let accounts: Signer[];

beforeEach(async () => {
  Store = await ethers.getContractFactory("Store");
  store = await Store.deploy();

  await store.addProduct("apple", 10);
  await store.addProduct("pear", 10);
  await store.addProduct("strawberry", 5);

  accounts = await ethers.getSigners();
});

describe("Store", () => {
  it("The owner of the store should be able to add new products and the quantity of them", async () => {
    await store.addQuantity("apple", 3);

    expect(await store.getProducts()).to.have.lengthOf(3);
    expect(await store.getProduct(0))
      .to.have.property("quantity")
      .to.equal(13);
  });

  it("The administrator should not be able to add the same product twice, just quantity", async () => {
    await expect(store.addProduct("apple", 4)).to.be.revertedWith(
      "Product already exists"
    );
  });

  it("Only owner should be able to add products or to update quantity", async () => {
    await expect(
      store.connect(accounts[1]).addProduct("peach", 4)
    ).to.be.revertedWith("Caller is not the owner");
    await expect(
      store.connect(accounts[1]).addQuantity("peach", 4)
    ).to.be.revertedWith("Caller is not the owner");
  });

  it("Buyers should be able to see the available products and buy them by their id", async () => {
    let product;

    // Check if buyer can see all products.
    expect(await store.connect(accounts[1]).getProducts()).to.have.lengthOf(3);

    // Check original state.
    product = await store.getProduct(0);
    expect(product.buyers).to.have.lengthOf(0);

    // Buy an apple.
    await store.connect(accounts[1]).buy(product.id, 3);
    product = await store.getProduct(product.id);
    expect(product.buyers).to.have.lengthOf(1);
    expect(product.buyers[0]).to.equal(await accounts[1].getAddress());
  });

  it("Buyers should be able to return products if they are not satisfied (within a 10 transactions)", async () => {
    await store.addQuantity("apple", 10);

    // Make first (0) transaction for account with index 1.
    await store.connect(accounts[1]).buy(1, 1);

    // Make 10 transactions.
    for (let i = 9; i >= 0; i--) {
      await store.connect(accounts[i]).buy(0, 1);
    }

    // Check if account with index 1 can return the product from his first (0) transaction.
    await expect(
      store.connect(accounts[1]).returnByProductId(1)
    ).to.be.revertedWith("The product can't be return");

    // Check if account with index 1 can return the product from his second (1) transaction.
    expect(await store.getBuyer(await accounts[1].getAddress()))
      .to.have.property("transactions")
      .to.have.lengthOf(2);

    await store.connect(accounts[1]).returnByProductId(0);

    expect(await store.getBuyer(await accounts[1].getAddress()))
      .to.have.property("transactions")
      .to.have.lengthOf(1);
  });

  it("A client cannot buy the same product more than one time", async () => {
    await store.connect(accounts[1]).buy(0, 1);
    await expect(store.connect(accounts[1]).buy(0, 1)).to.be.revertedWith(
      "The product already has been bought"
    );
  });

  it("The clients should not be able to buy a product more times than the quantity in the store", async () => {
    await store.connect(accounts[1]).buy(0, 5);
    await expect(store.connect(accounts[2]).buy(0, 6)).to.be.revertedWith(
      "Not enough in stock"
    );
    await store.connect(accounts[1]).returnByProductId(0);
    await store.connect(accounts[2]).buy(0, 6);
  });

  it("Everyone should be able to see the addresses of all clients that have ever bought a given product", async () => {
    const productId = 0;

    for (let index = 0; index < 4; index++) {
      await store.connect(accounts[index]).buy(productId, 1);
    }

    for (let index = 0; index < 4; index++) {
      const product = await store
        .connect(accounts[index])
        .getProduct(productId);

      for (
        let buyerIndex = 0;
        buyerIndex < product.buyers.length;
        buyerIndex++
      ) {
        expect(product.buyers[buyerIndex]).to.equal(
          await accounts[buyerIndex].getAddress()
        );
      }
    }
  });
});
