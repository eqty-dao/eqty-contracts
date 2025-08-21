import { expect } from "chai";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import hre from "hardhat";
import { parseEther } from "viem";

describe("EQTY Token", function () {
  async function deployEQTYFixture() {
    const [bridgeWallet, alice, bob] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();
    
    // Set mint deadline to 30 days from now
    const currentTime = await time.latest();
    const mintDeadline = BigInt(currentTime) + BigInt(30 * 24 * 60 * 60);
    
    const eqty = await hre.viem.deployContract("EQTY", [
      bridgeWallet.account.address,
      mintDeadline
    ]);
    
    return { eqty, bridgeWallet, alice, bob, publicClient, mintDeadline };
  }

  describe("Deployment", function () {
    it("Should set the correct bridge wallet", async function () {
      const { eqty, bridgeWallet } = await loadFixture(deployEQTYFixture);
      const actualBridge = await eqty.read.bridgeWallet();
      expect(actualBridge.toLowerCase()).to.equal(bridgeWallet.account.address.toLowerCase());
    });

    it("Should set the correct mint deadline", async function () {
      const { eqty, mintDeadline } = await loadFixture(deployEQTYFixture);
      expect(await eqty.read.mintDeadline()).to.equal(mintDeadline);
    });

    it("Should have zero initial supply", async function () {
      const { eqty } = await loadFixture(deployEQTYFixture);
      expect(await eqty.read.totalSupply()).to.equal(0n);
    });

    it("Should set the correct cap", async function () {
      const { eqty } = await loadFixture(deployEQTYFixture);
      const expectedCap = parseEther("500000000"); // 500 million
      expect(await eqty.read.cap()).to.equal(expectedCap);
    });

    it("Should revert if bridge wallet is zero address", async function () {
      const mintDeadline = BigInt(await time.latest()) + BigInt(30 * 24 * 60 * 60);
      
      try {
        await hre.viem.deployContract("EQTY", [
          "0x0000000000000000000000000000000000000000",
          mintDeadline
        ]);
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("InvalidBridgeWallet");
      }
    });

    it("Should revert if deadline is in the past", async function () {
      const [bridgeWallet] = await hre.viem.getWalletClients();
      const pastDeadline = BigInt(await time.latest()) - BigInt(1);
      
      try {
        await hre.viem.deployContract("EQTY", [
          bridgeWallet.account.address,
          pastDeadline
        ]);
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("DeadlineMustBeInFuture");
      }
    });
  });

  describe("Minting", function () {
    it("Should allow bridge wallet to mint tokens", async function () {
      const { eqty, bridgeWallet, alice } = await loadFixture(deployEQTYFixture);
      
      const mintAmount = parseEther("1000");
      await eqty.write.mint([alice.account.address, mintAmount], {
        account: bridgeWallet.account
      });
      
      expect(await eqty.read.balanceOf([alice.account.address])).to.equal(mintAmount);
      expect(await eqty.read.totalSupply()).to.equal(mintAmount);
    });

    it("Should emit BridgeMint event", async function () {
      const { eqty, bridgeWallet, alice, publicClient } = await loadFixture(deployEQTYFixture);
      
      const mintAmount = parseEther("1000");
      const hash = await eqty.write.mint([alice.account.address, mintAmount], {
        account: bridgeWallet.account
      });
      
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      const logs = await eqty.getEvents.BridgeMint({}, { fromBlock: receipt.blockNumber });
      
      expect(logs).to.have.lengthOf(1);
      expect(logs[0].args.to?.toLowerCase()).to.equal(alice.account.address.toLowerCase());
      expect(logs[0].args.amount).to.equal(mintAmount);
    });

    it("Should not allow non-bridge wallet to mint", async function () {
      const { eqty, alice } = await loadFixture(deployEQTYFixture);
      
      try {
        await eqty.write.mint([alice.account.address, parseEther("1000")], {
          account: alice.account
        });
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("NotBridgeWallet");
      }
    });


    it("Should not allow minting beyond deadline", async function () {
      const { eqty, bridgeWallet, alice, mintDeadline } = await loadFixture(deployEQTYFixture);
      
      // Advance time past deadline
      await time.increaseTo(mintDeadline + 1n);
      
      try {
        await eqty.write.mint([alice.account.address, parseEther("1000")], {
          account: bridgeWallet.account
        });
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("MintingPeriodExpired");
      }
    });

    it("Should not allow minting beyond cap", async function () {
      const { eqty, bridgeWallet, alice } = await loadFixture(deployEQTYFixture);
      
      const cap = await eqty.read.cap();
      const overAmount = cap + 1n;
      
      try {
        await eqty.write.mint([alice.account.address, overAmount], {
          account: bridgeWallet.account
        });
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("ERC20ExceededCap");
      }
    });

    it("Should allow minting up to exact cap", async function () {
      const { eqty, bridgeWallet, alice } = await loadFixture(deployEQTYFixture);
      
      const cap = await eqty.read.cap();
      
      await eqty.write.mint([alice.account.address, cap], {
        account: bridgeWallet.account
      });
      
      expect(await eqty.read.totalSupply()).to.equal(cap);
      
      // Try to mint one more token - should fail
      try {
        await eqty.write.mint([alice.account.address, 1n], {
          account: bridgeWallet.account
        });
        expect.fail("Should have reverted");
      } catch (error: any) {
        expect(error.message).to.include("ERC20ExceededCap");
      }
    });

    it("Should track total supply correctly across multiple mints", async function () {
      const { eqty, bridgeWallet, alice, bob } = await loadFixture(deployEQTYFixture);
      
      const firstMint = parseEther("1000");
      const secondMint = parseEther("2000");
      
      await eqty.write.mint([alice.account.address, firstMint], {
        account: bridgeWallet.account
      });
      expect(await eqty.read.totalSupply()).to.equal(firstMint);
      
      await eqty.write.mint([bob.account.address, secondMint], {
        account: bridgeWallet.account
      });
      expect(await eqty.read.totalSupply()).to.equal(firstMint + secondMint);
    });
  });

  describe("Burning", function () {
    it("Should allow users to burn their own tokens", async function () {
      const { eqty, bridgeWallet, alice } = await loadFixture(deployEQTYFixture);
      
      const mintAmount = parseEther("1000");
      await eqty.write.mint([alice.account.address, mintAmount], {
        account: bridgeWallet.account
      });
      
      const burnAmount = parseEther("100");
      await eqty.write.burn([burnAmount], {
        account: alice.account
      });
      
      expect(await eqty.read.balanceOf([alice.account.address])).to.equal(mintAmount - burnAmount);
      expect(await eqty.read.totalSupply()).to.equal(mintAmount - burnAmount);
    });

    it("Should allow approved spenders to burn tokens", async function () {
      const { eqty, bridgeWallet, alice, bob } = await loadFixture(deployEQTYFixture);
      
      const mintAmount = parseEther("1000");
      await eqty.write.mint([alice.account.address, mintAmount], {
        account: bridgeWallet.account
      });
      
      const burnAmount = parseEther("100");
      await eqty.write.approve([bob.account.address, burnAmount], {
        account: alice.account
      });
      
      await eqty.write.burnFrom([alice.account.address, burnAmount], {
        account: bob.account
      });
      
      expect(await eqty.read.balanceOf([alice.account.address])).to.equal(mintAmount - burnAmount);
      expect(await eqty.read.totalSupply()).to.equal(mintAmount - burnAmount);
    });
  });

  describe("Standard ERC20 Functions", function () {
    it("Should transfer tokens correctly", async function () {
      const { eqty, bridgeWallet, alice, bob } = await loadFixture(deployEQTYFixture);
      
      const mintAmount = parseEther("1000");
      await eqty.write.mint([alice.account.address, mintAmount], {
        account: bridgeWallet.account
      });
      
      const transferAmount = parseEther("100");
      await eqty.write.transfer([bob.account.address, transferAmount], {
        account: alice.account
      });
      
      expect(await eqty.read.balanceOf([alice.account.address])).to.equal(mintAmount - transferAmount);
      expect(await eqty.read.balanceOf([bob.account.address])).to.equal(transferAmount);
    });

    it("Should handle approve and transferFrom correctly", async function () {
      const { eqty, bridgeWallet, alice, bob } = await loadFixture(deployEQTYFixture);
      
      const mintAmount = parseEther("1000");
      await eqty.write.mint([alice.account.address, mintAmount], {
        account: bridgeWallet.account
      });
      
      const approveAmount = parseEther("100");
      await eqty.write.approve([bob.account.address, approveAmount], {
        account: alice.account
      });
      
      expect(await eqty.read.allowance([alice.account.address, bob.account.address])).to.equal(approveAmount);
      
      const transferAmount = parseEther("50");
      await eqty.write.transferFrom([alice.account.address, bob.account.address, transferAmount], {
        account: bob.account
      });
      
      expect(await eqty.read.balanceOf([alice.account.address])).to.equal(mintAmount - transferAmount);
      expect(await eqty.read.balanceOf([bob.account.address])).to.equal(transferAmount);
      expect(await eqty.read.allowance([alice.account.address, bob.account.address])).to.equal(approveAmount - transferAmount);
    });

    it("Should have correct name and symbol", async function () {
      const { eqty } = await loadFixture(deployEQTYFixture);
      
      expect(await eqty.read.name()).to.equal("EQTY");
      expect(await eqty.read.symbol()).to.equal("EQTY");
    });

    it("Should have 18 decimals", async function () {
      const { eqty } = await loadFixture(deployEQTYFixture);
      
      expect(await eqty.read.decimals()).to.equal(18);
    });
  });

});