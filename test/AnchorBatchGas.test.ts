import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import hre from "hardhat";
import { parseEther } from "viem";

describe("⛽ Anchor Batch Gas Costs", function () {
  async function deployFixture() {
    const [owner, bridgeWallet] = await hre.viem.getWalletClients();
    
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
    
    // Deploy batch test contract
    const batchTest = await hre.viem.deployContract("AnchorBatchTest", [anchor.address]);
    
    // Mint tokens to batch test contract and approve (using bridge wallet)
    await eqty.write.mint([batchTest.address, parseEther("10000")], {
      account: bridgeWallet.account
    });
    
    // Approve the anchor contract to burn tokens from batch test contract
    // Note: This would need to be done from the batch test contract in a real scenario
    // For testing, we'll set fee to 0 to focus on gas measurements
    await anchor.write.setAnchorFee([0n]);

    return { anchor, eqty, batchTest };
  }

  it("Batch: 1 anchor", async function () {
    const { batchTest } = await loadFixture(deployFixture);
    await batchTest.write.anchor001();
  });

  it("Batch: 10 anchors", async function () {
    const { batchTest } = await loadFixture(deployFixture);
    await batchTest.write.anchor010();
  });

  it("Batch: 50 anchors", async function () {
    const { batchTest } = await loadFixture(deployFixture);
    await batchTest.write.anchor050();
  });

  it("Batch: 100 anchors", async function () {
    const { batchTest } = await loadFixture(deployFixture);
    await batchTest.write.anchor100();
  });
});