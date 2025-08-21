import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import hre from "hardhat";
import type { Hash } from "viem";
import { parseEther } from "viem";

// Test specifically for gas reporter to show individual batch costs
describe("Anchor Batch Costs", function () {
  async function deployFixture() {
    const [owner, bridgeWallet, alice] = await hre.viem.getWalletClients();
    
    // Deploy EQTY token
    const mintDeadline = BigInt(Math.floor(Date.now() / 1000)) + BigInt(30 * 24 * 60 * 60);
    const eqty = await hre.viem.deployContract("EQTY", [
      bridgeWallet.account.address,
      mintDeadline
    ]);
    
    // Deploy Anchor
    const anchorFee = parseEther("0.01"); // 0.01 EQTY per anchor
    const anchor = await hre.viem.deployContract("Anchor", []);
    
    // Configure EQTY token and fee
    await anchor.write.setEqtyToken([eqty.address], { account: owner.account });
    await anchor.write.setAnchorFee([anchorFee], { account: owner.account });
    
    // Mint tokens and approve (using bridge wallet)
    await eqty.write.mint([alice.account.address, parseEther("10000")], {
      account: bridgeWallet.account
    });
    await eqty.write.approve([anchor.address, parseEther("10000")], { account: alice.account });

    return { anchor, eqty, alice };
  }

  it("Cost: 1 anchor", async function () {
    const { anchor, alice } = await loadFixture(deployFixture);
    
    await anchor.write.anchor([[{
      key: "0x0000000000000000000000000000000000000000000000000000000000000001" as Hash,
      value: "0x0000000000000000000000000000000000000000000000000000000000000002" as Hash,
    }]], { account: alice.account });
  });

  it("Cost: 10 anchors", async function () {
    const { anchor, alice } = await loadFixture(deployFixture);
    
    const anchors = Array.from({ length: 10 }, (_, i) => ({
      key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
      value: `0x${(i + 100).toString(16).padStart(64, "0")}` as Hash,
    }));

    await anchor.write.anchor([anchors], { account: alice.account });
  });

  it("Cost: 50 anchors", async function () {
    const { anchor, alice } = await loadFixture(deployFixture);
    
    const anchors = Array.from({ length: 50 }, (_, i) => ({
      key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
      value: `0x${(i + 1000).toString(16).padStart(64, "0")}` as Hash,
    }));

    await anchor.write.anchor([anchors], { account: alice.account });
  });

  it("Cost: 100 anchors", async function () {
    const { anchor, alice } = await loadFixture(deployFixture);
    
    const anchors = Array.from({ length: 100 }, (_, i) => ({
      key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
      value: `0x${(i + 10000).toString(16).padStart(64, "0")}` as Hash,
    }));

    await anchor.write.anchor([anchors], { account: alice.account });
  });
});

// Separate test for zero-fee gas measurements
describe("Anchor Pure Gas (No Fee)", function () {
  async function deployFixture() {
    const [owner, bridgeWallet, alice] = await hre.viem.getWalletClients();
    
    // Deploy EQTY token
    const mintDeadline = BigInt(Math.floor(Date.now() / 1000)) + BigInt(30 * 24 * 60 * 60);
    const eqty = await hre.viem.deployContract("EQTY", [
      bridgeWallet.account.address,
      mintDeadline
    ]);
    
    // Deploy Anchor
    const anchor = await hre.viem.deployContract("Anchor", []);
    
    // Configure EQTY token with ZERO fee
    await anchor.write.setEqtyToken([eqty.address], { account: owner.account });
    await anchor.write.setAnchorFee([0n], { account: owner.account }); // Zero fee

    return { anchor, alice };
  }

  it("Pure gas: 1 anchor", async function () {
    const { anchor, alice } = await loadFixture(deployFixture);
    
    await anchor.write.anchor([[{
      key: "0x0000000000000000000000000000000000000000000000000000000000000001" as Hash,
      value: "0x0000000000000000000000000000000000000000000000000000000000000002" as Hash,
    }]], { account: alice.account });
  });

  it("Pure gas: 100 anchors", async function () {
    const { anchor, alice } = await loadFixture(deployFixture);
    
    const anchors = Array.from({ length: 100 }, (_, i) => ({
      key: `0x${i.toString(16).padStart(64, "0")}` as Hash,
      value: `0x${(i + 10000).toString(16).padStart(64, "0")}` as Hash,
    }));

    await anchor.write.anchor([anchors], { account: alice.account });
  });
});