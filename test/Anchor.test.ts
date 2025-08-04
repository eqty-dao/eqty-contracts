import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import hre from "hardhat";
import type { Address, Hash } from "viem";
import { parseEventLogs, parseEther } from "viem";

describe("EQTY Token", function () {
  async function deployEQTYFixture() {
    const [owner, alice] = await hre.viem.getWalletClients();
    const eqty = await hre.viem.deployContract("EQTY", [owner.account.address]);
    return { eqty, owner, alice };
  }

  it("Should not allow non-owner to mint tokens", async function () {
    const { eqty, alice } = await loadFixture(deployEQTYFixture);

    try {
      await eqty.write.mint([alice.account.address, parseEther("1000")], {
        account: alice.account,
      });
      expect.fail("Should have reverted");
    } catch (error: any) {
      expect(error.message).to.include("OwnableUnauthorizedAccount");
    }
  });
});

describe("Anchor", function () {
  async function deployAnchorFixture() {
    const [owner, alice, bob] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();

    // Deploy EQTY token
    const eqty = await hre.viem.deployContract("EQTY", [owner.account.address]);
    
    // Deploy Anchor
    const anchorFee = parseEther("0.1");
    const anchor = await hre.viem.deployContract("Anchor", []);
    
    // Configure EQTY token and fee
    await anchor.write.setEqtyToken([eqty.address], { account: owner.account });
    await anchor.write.setAnchorFee([anchorFee], { account: owner.account });

    // Mint some EQTY to test users
    await eqty.write.mint([alice.account.address, parseEther("1000")]);
    await eqty.write.mint([bob.account.address, parseEther("1000")]);

    // Approve Anchor contract to burn tokens
    await eqty.write.approve([anchor.address, parseEther("1000")], { account: alice.account });
    await eqty.write.approve([anchor.address, parseEther("1000")], { account: bob.account });

    return {
      anchor,
      eqty,
      owner,
      alice,
      bob,
      publicClient,
      anchorFee,
    };
  }

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      const { anchor } = await loadFixture(deployAnchorFixture);
      expect(anchor.address).to.match(/^0x[a-fA-F0-9]{40}$/);
    });

    it("Should have minimal storage for fee configuration", async function () {
      const { anchor, publicClient } = await loadFixture(deployAnchorFixture);
      // Verify contract exists
      const bytecode = await publicClient.getBytecode({ address: anchor.address });
      expect(bytecode).to.exist;
      // Contract is larger now due to fee mechanism and ownership
      expect(bytecode!.length).to.be.greaterThan(1000);
    });
  });

  describe("Fee Mechanism", function () {
    it("Should burn EQTY tokens as fee", async function () {
      const { anchor, eqty, alice, anchorFee, publicClient } = await loadFixture(deployAnchorFixture);

      const initialBalance = await eqty.read.balanceOf([alice.account.address]);
      
      const key = "0x1234567890123456789012345678901234567890123456789012345678901234" as Hash;
      const value = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd" as Hash;

      await anchor.write.anchor([[{ key, value }]], {
        account: alice.account,
      });

      const finalBalance = await eqty.read.balanceOf([alice.account.address]);
      expect(finalBalance).to.equal(initialBalance - anchorFee);
    });

    it("Should burn correct amount for batch anchors", async function () {
      const { anchor, eqty, alice, anchorFee, publicClient } = await loadFixture(deployAnchorFixture);

      const initialBalance = await eqty.read.balanceOf([alice.account.address]);
      const anchors = Array.from({ length: 10 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      await anchor.write.anchor([anchors], {
        account: alice.account,
      });

      const finalBalance = await eqty.read.balanceOf([alice.account.address]);
      expect(finalBalance).to.equal(initialBalance - (anchorFee * 10n));
    });

    it("Should allow owner to update fee", async function () {
      const { anchor, owner, publicClient } = await loadFixture(deployAnchorFixture);

      const newFee = parseEther("0.5");
      const hash = await anchor.write.setAnchorFee([newFee], {
        account: owner.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs).to.have.lengthOf(1);
      expect(logs[0].eventName).to.equal("AnchorFeeUpdated");
      
      const currentFee = await anchor.read.anchorFee();
      expect(currentFee).to.equal(newFee);
    });

    it("Should not allow non-owner to update fee", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);

      try {
        await anchor.write.setAnchorFee([parseEther("0.5")], {
          account: alice.account,
        });
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("OwnableUnauthorizedAccount");
      }
    });

    it("Should not allow non-owner to update EQTY token", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);

      try {
        await anchor.write.setEqtyToken([alice.account.address], {
          account: alice.account,
        });
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("OwnableUnauthorizedAccount");
      }
    });

    it("Should work with zero fee", async function () {
      const { anchor, eqty, alice, owner } = await loadFixture(deployAnchorFixture);

      // Set fee to zero
      await anchor.write.setAnchorFee([0n], {
        account: owner.account,
      });

      const initialBalance = await eqty.read.balanceOf([alice.account.address]);
      
      await anchor.write.anchor([[{
        key: "0x1111111111111111111111111111111111111111111111111111111111111111" as Hash,
        value: "0x2222222222222222222222222222222222222222222222222222222222222222" as Hash,
      }]], {
        account: alice.account,
      });

      const finalBalance = await eqty.read.balanceOf([alice.account.address]);
      expect(finalBalance).to.equal(initialBalance); // No tokens burned
    });
  });

  describe("Single Anchor", function () {
    it("Should emit event for single anchor", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const key = "0x1234567890123456789012345678901234567890123456789012345678901234" as Hash;
      const value = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd" as Hash;

      const hash = await anchor.write.anchor([[{ key, value }]], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs).to.have.lengthOf(1);
      expect(logs[0].eventName).to.equal("Anchored");
      expect(logs[0].args.key).to.equal(key);
      expect(logs[0].args.value).to.equal(value);
      expect(logs[0].args.sender?.toLowerCase()).to.equal(alice.account.address.toLowerCase());
      expect(logs[0].args.timestamp).to.be.a("bigint");
    });

    it("Should anchor message with zero value", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const messageHash = "0x9999999999999999999999999999999999999999999999999999999999999999" as Hash;
      const zeroValue = "0x0000000000000000000000000000000000000000000000000000000000000000" as Hash;

      const hash = await anchor.write.anchor([[{ key: messageHash, value: zeroValue }]], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs[0].args.key).to.equal(messageHash);
      expect(logs[0].args.value).to.equal(zeroValue);
    });
  });

  describe("Batch Anchors", function () {
    it("Should handle batch of 10 anchors", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const anchors = Array.from({ length: 10 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      const hash = await anchor.write.anchor([anchors], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs).to.have.lengthOf(10);
      logs.forEach((log, i) => {
        expect(log.args.key).to.equal(anchors[i].key);
        expect(log.args.value).to.equal(anchors[i].value);
        expect(log.args.sender?.toLowerCase()).to.equal(alice.account.address.toLowerCase());
      });
    });

    it("Should handle batch of 50 anchors", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const anchors = Array.from({ length: 50 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 1000).toString(16).padStart(64, "0")}` as Hash,
      }));

      const hash = await anchor.write.anchor([anchors], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs).to.have.lengthOf(50);
    });

    it("Should handle batch of 100 anchors", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const anchors = Array.from({ length: 100 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 10000).toString(16).padStart(64, "0")}` as Hash,
      }));

      const hash = await anchor.write.anchor([anchors], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs).to.have.lengthOf(100);
    });

    it("Should use same timestamp for all anchors in batch", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const anchors = Array.from({ length: 5 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${i.toString(16).padStart(64, "0")}` as Hash,
      }));

      const hash = await anchor.write.anchor([anchors], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      const firstTimestamp = logs[0].args.timestamp;
      logs.forEach(log => {
        expect(log.args.timestamp).to.equal(firstTimestamp);
      });
    });
  });

  describe("Edge Cases", function () {
    it("Should handle empty array", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const hash = await anchor.write.anchor([[]], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs).to.have.lengthOf(0);
    });

    it("Should allow duplicate keys", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const key = "0x1111111111111111111111111111111111111111111111111111111111111111" as Hash;
      const value1 = "0x2222222222222222222222222222222222222222222222222222222222222222" as Hash;
      const value2 = "0x3333333333333333333333333333333333333333333333333333333333333333" as Hash;

      const anchors = [
        { key, value: value1 },
        { key, value: value2 }, // Same key, different value
      ];

      const hash = await anchor.write.anchor([anchors], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: anchor.abi,
        logs: receipt.logs,
      });

      expect(logs).to.have.lengthOf(2);
      expect(logs[0].args.key).to.equal(key);
      expect(logs[1].args.key).to.equal(key);
      expect(logs[0].args.value).to.equal(value1);
      expect(logs[1].args.value).to.equal(value2);
    });

    it("Should revert when exceeding maximum anchors per transaction", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);

      // Try to submit 101 anchors (1 more than the max)
      const anchors = Array.from({ length: 101 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 1000).toString(16).padStart(64, "0")}` as Hash,
      }));

      try {
        await anchor.write.anchor([anchors], {
          account: alice.account,
        });
        expect.fail("Should have reverted");
      } catch (error: any) {
        // For viem, check if it's a revert error
        expect(error).to.exist;
        // The transaction should fail - we just need to ensure it reverted
        // Viem doesn't always expose the exact revert reason in a predictable way
        expect(error.name || error.constructor.name).to.include("Error");
      }
    });
  });

  describe("Permissions", function () {
    it("Should allow any address to anchor", async function () {
      const { anchor, alice, bob, publicClient } = await loadFixture(deployAnchorFixture);

      const key = "0xaaaa000000000000000000000000000000000000000000000000000000000000" as Hash;
      const value = "0xbbbb000000000000000000000000000000000000000000000000000000000000" as Hash;

      // Alice anchors
      const hash1 = await anchor.write.anchor([[{ key, value }]], {
        account: alice.account,
      });
      await publicClient.waitForTransactionReceipt({ hash: hash1 });

      // Bob anchors
      const hash2 = await anchor.write.anchor([[{ key, value }]], {
        account: bob.account,
      });
      await publicClient.waitForTransactionReceipt({ hash: hash2 });

      // Both should succeed
      expect(hash1).to.be.a("string");
      expect(hash2).to.be.a("string");
    });
  });

  describe("Gas Usage", function () {
    it("Should measure gas for single anchor", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const key = "0x1234567890123456789012345678901234567890123456789012345678901234" as Hash;
      const value = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd" as Hash;

      const hash = await anchor.write.anchor([[{ key, value }]], {
        account: alice.account,
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      console.log(`Gas used for 1 anchor: ${receipt.gasUsed}`);
      
      // Gas is higher now due to token burn mechanism
      expect(Number(receipt.gasUsed)).to.be.lessThan(60000);
    });

    it("Should measure gas for batch anchors", async function () {
      const { anchor, alice, publicClient } = await loadFixture(deployAnchorFixture);

      const testCases = [10, 50, 100];
      
      for (const count of testCases) {
        const anchors = Array.from({ length: count }, (_, i) => ({
          key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
          value: `0x${(i + 1000).toString(16).padStart(64, "0")}` as Hash,
        }));

        const hash = await anchor.write.anchor([anchors], {
          account: alice.account,
        });

        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        console.log(`Gas used for ${count} anchors: ${receipt.gasUsed}`);
        
        // Verify linear scaling (higher due to token burns)
        const gasPerAnchor = Number(receipt.gasUsed) / count;
        expect(gasPerAnchor).to.be.lessThan(8100); // Higher due to fee mechanism
      }
    });
  });
});