// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EQTY
 * @notice The EQTY token used for anchoring fees on the EQTY protocol
 * @dev ERC20 token with burn functionality and minting controlled by owner
 * 
 * Key features:
 * - Burnable: Required for fee mechanism in Anchor contract
 * - Mintable: Only by owner (for initial distribution and migration)
 * - Standard ERC20: Compatible with all wallets and DEXs
 */
contract EQTY is ERC20, ERC20Burnable, Ownable {
    /**
     * @notice Constructor sets token name, symbol, and initial owner
     * @param initialOwner Address that will own the contract and can mint tokens
     */
    constructor(address initialOwner) 
        ERC20("EQTY", "EQTY") 
        Ownable(initialOwner) 
    {
        // No initial supply - tokens must be minted
    }

    /**
     * @notice Mint new EQTY tokens
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint (in wei)
     * @dev Only callable by owner. Used for initial distribution and LTO migration
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Allows approved spenders to burn tokens on behalf of an account
     * @param account The account whose tokens will be burned
     * @param amount The amount of tokens to burn
     * @dev This is used by the Anchor contract to burn fees without requiring approve()
     */
    function burnFrom(address account, uint256 amount) public override {
        // This will check allowance and burn in one step
        super.burnFrom(account, amount);
    }
}