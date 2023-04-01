const {
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("JointBankAccount", function () {
  async function deployJointBankAccount() {
    const [addr0, addr1, addr2, addr3] = await ethers.getSigners();

    const BankAccount = await ethers.getContractFactory("JointBankAccount");
    const bankAccount = await BankAccount.deploy();

    return { bankAccount, addr0, addr1, addr2, addr3 };
  }

  describe("Deployment", () => {
    it("should deploy without error", async () => {
      await loadFixture(deployJointBankAccount);
    })
  })

  describe("Creating an account", () => {
    it("should allow creating a single user account", async () => {
      const { bankAccount, addr0 } = await loadFixture(deployJointBankAccount);
      await bankAccount.connect(addr0).createAccount([]);
      const accounts = await bankAccount.connect(addr0).getAccounts();
      expect(accounts.length).to.equal(1);
    })
  })
});
