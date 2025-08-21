// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
 * @title EQTY
 * @notice The EQTY token used for anchoring fees on the EQTY protocol
 * @dev ERC20 token with burn functionality and minting controlled by bridge wallet
 * 
 * Key features:
 * - Burnable: Required for fee mechanism in Anchor contract
 * - Capped Supply: 500 million tokens maximum (using ERC20Capped)
 * - Bridge Mintable: Only bridge wallet can mint until specified timestamp
 * - Standard ERC20: Compatible with all wallets and DEXs
 */
contract EQTY is ERC20, ERC20Burnable, ERC20Capped {
    uint256 private constant TOTAL_SUPPLY = 500_000_000 ether; // 500 million tokens
    
    address public immutable bridgeWallet;
    uint256 public immutable mintDeadline;

    error MintingPeriodExpired();
    error NotBridgeWallet();

    event BridgeMint(address indexed to, uint256 amount);

    /**
     * @notice Constructor sets token name, symbol, cap, bridge wallet, and minting deadline
     * @param _bridgeWallet Address of the bridge wallet that can mint tokens
     * @param _mintDeadline Timestamp after which minting is no longer allowed
     */
    constructor(
        address _bridgeWallet,
        uint256 _mintDeadline
    ) 
        ERC20("EQTY", "EQTY")
        ERC20Capped(TOTAL_SUPPLY) 
    {
        require(_bridgeWallet != address(0), "Invalid bridge wallet");
        require(_mintDeadline > block.timestamp, "Deadline must be in future");
        
        bridgeWallet = _bridgeWallet;
        mintDeadline = _mintDeadline;
    }

    /**
     * @notice Mint new EQTY tokens (only callable by bridge wallet before deadline)
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint (in wei)
     * @dev Only callable by bridge wallet before mintDeadline
     * @dev The cap check is handled by ERC20Capped in _update
     */
    function mint(address to, uint256 amount) external {
        if (msg.sender != bridgeWallet) revert NotBridgeWallet();
        if (block.timestamp > mintDeadline) revert MintingPeriodExpired();
        
        _mint(to, amount);
        
        emit BridgeMint(to, amount);
    }
    
    /**
     * @dev Required override for ERC20Capped compatibility
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
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