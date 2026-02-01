// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IEQTY
 * @notice Interface for EQTY token with burn functionality
 */
interface IEQTY is IERC20 {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title RedeemEQTY
 * @notice Allows users to redeem EQTY tokens for ETH collected from Ownables fees
 * @dev Optimized for gas efficiency with packed storage
 * 
 * Key mechanics:
 * - Receive ETH from Ownables fee payments
 * - Anyone can send EQTY to receive all available ETH
 * - EQTY is burned (deflationary) with optional foundation fee
 * - Optional foundation fees on both ETH and EQTY (default 0%)
 */
contract RedeemEQTY is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // ============ Constants ============
    
    /// @notice Maximum foundation fee in basis points (100% = 10000 bps)
    uint16 public constant MAX_FEE_BPS = 10_000;
    
    // ============ Immutables ============
    
    /// @notice EQTY token contract
    IEQTY public immutable eqtyToken;
    
    // ============ Packed Storage (Slot 1) ============
    
    /// @notice Amount of EQTY required to redeem (max ~340 undecillion with uint128)
    uint128 public redeemAmount;
    
    /// @notice Foundation fee on ETH in basis points (max 10000)
    uint16 public foundationEthFeeBps;
    
    /// @notice Foundation fee on EQTY in basis points (max 10000)
    uint16 public foundationEqtyFeeBps;
    
    // ============ Storage (Slots 2-4) ============
    
    /// @notice Address to receive foundation fees
    address public foundationWallet;
    
    /// @notice Accumulated ETH fees available for withdrawal
    uint256 public pendingFoundationEth;
    
    /// @notice Accumulated EQTY fees available for withdrawal
    uint256 public pendingFoundationEqty;
    
    // ============ Events ============
    
    event Redeemed(
        address indexed redeemer, 
        uint256 eqtyBurned, 
        uint256 eqtyToFoundation,
        uint256 ethReceived,
        uint256 ethToFoundation
    );
    event FoundationEthFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event FoundationEqtyFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event FoundationWalletUpdated(address oldWallet, address newWallet);
    event FoundationEthWithdrawn(address indexed to, uint256 amount);
    event FoundationEqtyWithdrawn(address indexed to, uint256 amount);
    event RedeemAmountUpdated(uint128 oldAmount, uint128 newAmount);
    event ETHReceived(address indexed from, uint256 amount);
    
    // ============ Errors ============
    
    error InsufficientETH();
    error InsufficientEQTYAllowance();
    error InsufficientEQTYBalance();
    error FeeTooHigh();
    error RedeemAmountTooLow();
    error InvalidAddress();
    error WithdrawalFailed();
    error NoFeesToWithdraw();
    
    // ============ Constructor ============
    
    /**
     * @notice Deploy the Redeem contract
     * @param _eqtyToken Address of the EQTY token contract
     * @param _foundationWallet Address to receive foundation fees
     */
    constructor(
        address _eqtyToken,
        address _foundationWallet
    ) Ownable(msg.sender) {
        if (_eqtyToken == address(0)) revert InvalidAddress();
        if (_foundationWallet == address(0)) revert InvalidAddress();
        
        eqtyToken = IEQTY(_eqtyToken);
        foundationWallet = _foundationWallet;
        foundationEthFeeBps = 0;
        foundationEqtyFeeBps = 0;
        redeemAmount = 10_000 ether;
    }
    
    // ============ External Functions ============
    
    /**
     * @notice Receive ETH from Ownables payments
     */
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }
    
    /**
     * @notice Redeem EQTY tokens for ETH
     * @dev Burns EQTY from caller (minus foundation fee) and sends ETH (minus foundation fee)
     */
    function redeem() external nonReentrant {
        uint256 ethBalance = address(this).balance - pendingFoundationEth;
        if (ethBalance == 0) revert InsufficientETH();
        
        // Cache storage reads
        uint256 amount = redeemAmount;
        uint256 ethFeeBps = foundationEthFeeBps;
        uint256 eqtyFeeBps = foundationEqtyFeeBps;
        
        // Check allowance and balance
        if (eqtyToken.allowance(msg.sender, address(this)) < amount) {
            revert InsufficientEQTYAllowance();
        }
        if (eqtyToken.balanceOf(msg.sender) < amount) {
            revert InsufficientEQTYBalance();
        }
        
        // Calculate fees using unchecked for gas savings (overflow impossible with uint16 fees)
        uint256 ethFee;
        uint256 ethToSend;
        uint256 eqtyFee;
        uint256 eqtyToBurn;
        
        unchecked {
            ethFee = (ethBalance * ethFeeBps) / 10_000;
            ethToSend = ethBalance - ethFee;
            eqtyFee = (amount * eqtyFeeBps) / 10_000;
            eqtyToBurn = amount - eqtyFee;
        }
        
        // Accumulate foundation fees
        pendingFoundationEth += ethFee;
        pendingFoundationEqty += eqtyFee;
        
        // Transfer EQTY from user
        if (eqtyFee > 0) {
            eqtyToken.transferFrom(msg.sender, address(this), eqtyFee);
        }
        eqtyToken.burnFrom(msg.sender, eqtyToBurn);
        
        // Send ETH to redeemer
        (bool success, ) = msg.sender.call{value: ethToSend}("");
        if (!success) revert WithdrawalFailed();
        
        emit Redeemed(msg.sender, eqtyToBurn, eqtyFee, ethToSend, ethFee);
    }
    
    /**
     * @notice Get the amount of ETH available for redemption
     */
    function availableETH() external view returns (uint256) {
        return address(this).balance - pendingFoundationEth;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update the foundation ETH fee percentage
     * @param _newFeeBps New fee in basis points (max 10000 = 100%)
     */
    function setFoundationEthFee(uint16 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        
        uint16 oldFee = foundationEthFeeBps;
        foundationEthFeeBps = _newFeeBps;
        
        emit FoundationEthFeeUpdated(oldFee, _newFeeBps);
    }
    
    /**
     * @notice Update the foundation EQTY fee percentage
     * @param _newFeeBps New fee in basis points (max 10000 = 100%)
     */
    function setFoundationEqtyFee(uint16 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        
        uint16 oldFee = foundationEqtyFeeBps;
        foundationEqtyFeeBps = _newFeeBps;
        
        emit FoundationEqtyFeeUpdated(oldFee, _newFeeBps);
    }
    
    /**
     * @notice Update the redeem amount
     * @param _newAmount New amount of EQTY required (minimum 1 wei)
     */
    function setRedeemAmount(uint128 _newAmount) external onlyOwner {
        if (_newAmount == 0) revert RedeemAmountTooLow();
        
        uint128 oldAmount = redeemAmount;
        redeemAmount = _newAmount;
        
        emit RedeemAmountUpdated(oldAmount, _newAmount);
    }
    
    /**
     * @notice Update the foundation wallet address
     */
    function setFoundationWallet(address _newWallet) external onlyOwner {
        if (_newWallet == address(0)) revert InvalidAddress();
        
        address oldWallet = foundationWallet;
        foundationWallet = _newWallet;
        
        emit FoundationWalletUpdated(oldWallet, _newWallet);
    }
    
    /**
     * @notice Withdraw accumulated foundation ETH fees
     */
    function withdrawFoundationEth() external {
        uint256 amount = pendingFoundationEth;
        if (amount == 0) revert NoFeesToWithdraw();
        
        pendingFoundationEth = 0;
        
        (bool success, ) = foundationWallet.call{value: amount}("");
        if (!success) revert WithdrawalFailed();
        
        emit FoundationEthWithdrawn(foundationWallet, amount);
    }
    
    /**
     * @notice Withdraw accumulated foundation EQTY fees
     */
    function withdrawFoundationEqty() external {
        uint256 amount = pendingFoundationEqty;
        if (amount == 0) revert NoFeesToWithdraw();
        
        pendingFoundationEqty = 0;
        
        IERC20(address(eqtyToken)).safeTransfer(foundationWallet, amount);
        
        emit FoundationEqtyWithdrawn(foundationWallet, amount);
    }
}
