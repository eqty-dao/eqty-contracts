import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import hre from "hardhat";
import type { Hash } from "viem";

// Separate test file for detailed gas measurements
describe("Anchor Gas Analysis", function () {
  async function deployAnchorFixture() {
    const [owner, bridgeWallet, alice] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();
    
    // Deploy EQTY token
    const mintDeadline = BigInt(Math.floor(Date.now() / 1000)) + BigInt(30 * 24 * 60 * 60);
    const eqty = await hre.viem.deployContract("EQTY", [
      bridgeWallet.account.address,
      mintDeadline
    ]);
    
    // Deploy Anchor
    const anchor = await hre.viem.deployContract("Anchor", []);
    
    // Configure EQTY token with zero fee for gas measurements
    await anchor.write.setEqtyToken([eqty.address], { account: owner.account });
    await anchor.write.setAnchorFee([0n], { account: owner.account }); // Zero fee for pure gas measurements

    return { anchor, eqty, owner, alice, publicClient };
  }

  describe("Individual Batch Sizes", function () {
    it("Gas for 1 anchor", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      
      await anchor.write.anchor([[{
        key: "0x0000000000000000000000000000000000000000000000000000000000000001" as Hash,
        value: "0x0000000000000000000000000000000000000000000000000000000000000002" as Hash,
      }]], { account: alice.account });
    });

    it("Gas for 5 anchors", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      
      const anchors = Array.from({ length: 5 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      await anchor.write.anchor([anchors], { account: alice.account });
    });

    it("Gas for 10 anchors", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      
      const anchors = Array.from({ length: 10 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      await anchor.write.anchor([anchors], { account: alice.account });
    });

    it("Gas for 25 anchors", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      
      const anchors = Array.from({ length: 25 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      await anchor.write.anchor([anchors], { account: alice.account });
    });

    it("Gas for 50 anchors", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      
      const anchors = Array.from({ length: 50 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      await anchor.write.anchor([anchors], { account: alice.account });
    });

    it("Gas for 75 anchors", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      
      const anchors = Array.from({ length: 75 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      await anchor.write.anchor([anchors], { account: alice.account });
    });

    it("Gas for 100 anchors", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      
      const anchors = Array.from({ length: 100 }, (_, i) => ({
        key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
        value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
      }));

      await anchor.write.anchor([anchors], { account: alice.account });
    });
  });

  describe("Edge Cases", function () {
    it("Gas for empty array", async function () {
      const { anchor, alice } = await loadFixture(deployAnchorFixture);
      await anchor.write.anchor([[]], { account: alice.account });
    });
  });
});