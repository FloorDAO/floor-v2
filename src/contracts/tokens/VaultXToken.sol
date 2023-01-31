//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {OwnableUpgradeable} from '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {ERC20Upgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol';

import {SafeMathAlt} from '../utils/SafeMath.sol';
import {SafeMathInt} from '../utils/SafeMathInt.sol';

import {IVaultXToken} from '../../interfaces/tokens/VaultXToken.sol';

/// If there is a zero supply of the VaultXToken then there is no-one to distribute
/// rewards to.
error TotalSupplyIsZero();

/// If a zero amount is sent to be distributed
error CannotDistributeZeroRewards();

/**
 * VaultXToken - (Based on Dividend Token)
 * @author Roger Wu (https://github.com/roger-wu)
 *
 * A mintable ERC20 token that allows anyone to pay and distribute a target token
 * to token holders as dividends and allows token holders to withdraw their dividends.
 */
contract VaultXToken is ERC20Upgradeable, IVaultXToken, OwnableUpgradeable {
    using SafeMathAlt for uint;
    using SafeMathInt for int;
    using SafeERC20 for IERC20;

    /// The ERC20 token that will be distributed as rewards
    IERC20 public target;

    // With `magnitude`, we can properly distribute dividends even if the amount of received
    // target is small. For more discussion about choosing the value of `magnitude`:
    // https://github.com/ethereum/EIPs/issues/1726#issuecomment-472352728
    uint internal constant magnitude = 2 ** 128;
    uint internal magnifiedRewardPerShare;

    /**
     * About dividendCorrection:
     *
     * If the token balance of a `_user` is never changed, the dividend of `_user` can be computed with:
     * `dividendOf(_user) = dividendPerShare * balanceOf(_user)`.
     *
     * When `balanceOf(_user)` is changed (via minting/burning/transferring tokens),
     * `dividendOf(_user)` should not be changed, but the computed value of
     * `dividendPerShare * balanceOf(_user)` is changed.
     *
     * To keep the `dividendOf(_user)` unchanged, we add a correction term:
     * `dividendOf(_user) = dividendPerShare * balanceOf(_user) + dividendCorrectionOf(_user)`,
     * where `dividendCorrectionOf(_user)` is updated whenever `balanceOf(_user)` is changed:
     * `dividendCorrectionOf(_user) = dividendPerShare * (old balanceOf(_user)) - (new balanceOf(_user))`.
     *
     * So now `dividendOf(_user)` returns the same value before and after `balanceOf(_user)` is changed.
     */
    mapping(address => int) internal magnifiedRewardCorrections;
    mapping(address => uint) internal withdrawnRewards;

    /**
     * Set up our required parameters.
     *
     * @param _target ERC20 contract address used for reward distribution
     * @param _name Name of our xToken
     * @param _symbol Symbol of our xToken
     */
    function initialize(address _target, string memory _name, string memory _symbol) public initializer {
        __Ownable_init();
        __ERC20_init(_name, _symbol);

        target = IERC20(_target);
    }

    /**
     * Transfers the token from the called to the recipient.
     *
     * @param recipient Recipient of the tokens
     * @param amount Amount of token to be sent
     *
     * TODO: Does this want to be disabled?
     */
    function transfer(address recipient, uint amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, 'ERC20: transfer amount exceeds allowance'));

        return true;
    }

    /**
     * Allows the owner of the xToken (the parent vault) to mint.
     *
     * @param account Recipient of the tokens
     * @param amount Amount of token to be minted
     */
    function mint(address account, uint amount) public virtual onlyOwner {
        _mint(account, amount);
    }

    /**
     * Destroys `amount` tokens from `account`, without deducting from the caller's
     * allowance. Dangerous.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * @param account Address that will have their tokens burned
     * @param amount Amount of token to be burned
     */
    function burnFrom(address account, uint amount) public virtual onlyOwner {
        _burn(account, amount);
    }

    /**
     * Distributes target to token holders as dividends.
     *
     * It emits the `RewardsDistributed` event if the amount of received target is greater than 0.
     * About undistributed target tokens:
     *
     * In each distribution, there is a small amount of target not distributed, the magnified amount
     * of which is `(amount * magnitude) % totalSupply()`. With a well-chosen `magnitude`, the
     * amount of undistributed target (de-magnified) in a distribution can be less than 1 wei.
     *
     * We can actually keep track of the undistributed target in a distribution and try to distribute
     * it in the next distribution, but keeping track of such data on-chain costs much more than
     * the saved target, so we don't do that.
     *
     * @dev It reverts if the total supply of tokens is 0.
     *
     * @param amount Amount of rewards to distribute amongst holders
     */
    function distributeRewards(uint amount) external virtual onlyOwner {
        // RewardDist: 0 supply
        if (totalSupply() == 0) {
            revert TotalSupplyIsZero();
        }

        // RewardDist: 0 amount
        if (amount == 0) {
            revert CannotDistributeZeroRewards();
        }

        // We assume the FLOOR tokens have already been sent
        magnifiedRewardPerShare = magnifiedRewardPerShare.add((amount).mul(magnitude) / totalSupply());

        emit RewardsDistributed(msg.sender, amount);
    }

    /**
     * Withdraws the target distributed to the sender.
     *
     * @dev It emits a `RewardWithdrawn` event if the amount of withdrawn target is greater than 0.
     *
     * @param user User to withdraw rewards to
     */
    function withdrawReward(address user) external {
        uint _withdrawableReward = withdrawableRewardOf(user);
        if (_withdrawableReward != 0) {
            withdrawnRewards[user] = withdrawnRewards[user].add(_withdrawableReward);
            target.transfer(user, _withdrawableReward);
            emit RewardWithdrawn(user, _withdrawableReward);
        }
    }

    /**
     * View the amount of dividend in wei that an address can withdraw.
     *
     * @param _owner The address of a token holder
     *
     * @return The amount of dividend in wei that `_owner` can withdraw
     */
    function dividendOf(address _owner) public view returns (uint) {
        return withdrawableRewardOf(_owner);
    }

    /**
     * View the amount of dividend in wei that an address can withdraw.
     *
     * @param _owner The address of a token holder
     *
     * @return The amount of dividend in wei that `_owner` can withdraw
     */
    function withdrawableRewardOf(address _owner) internal view returns (uint) {
        return accumulativeRewardOf(_owner).sub(withdrawnRewards[_owner]);
    }

    /**
     * View the amount of dividend in wei that an address has withdrawn.
     *
     * @param _owner The address of a token holder
     *
     * @return The amount of dividend in wei that `_owner` has withdrawn
     */
    function withdrawnRewardOf(address _owner) public view returns (uint) {
        return withdrawnRewards[_owner];
    }

    /**
     * View the amount of dividend in wei that an address has earned in total.
     *
     * @param _owner The address of a token holder
     *
     * @return The amount of dividend in wei that `_owner` has earned in total
     */
    function accumulativeRewardOf(address _owner) public view returns (uint) {
        return magnifiedRewardPerShare.mul(balanceOf(_owner)).toInt256().add(magnifiedRewardCorrections[_owner]).toUint256Safe() / magnitude;
    }

    /**
     * Internal function that transfer tokens from one address to another.
     *
     * Update magnifiedRewardCorrections to keep dividends unchanged.
     *
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param value The amount to be transferred
     */
    function _transfer(address from, address to, uint value) internal override {
        super._transfer(from, to, value);

        int _magCorrection = magnifiedRewardPerShare.mul(value).toInt256();

        magnifiedRewardCorrections[from] = magnifiedRewardCorrections[from].add(_magCorrection);
        magnifiedRewardCorrections[to] = magnifiedRewardCorrections[to].sub(_magCorrection);
    }

    /**
     * Internal function that mints tokens to an account.
     *
     * Update magnifiedRewardCorrections to keep dividends unchanged.
     *
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint value) internal override {
        super._mint(account, value);
        magnifiedRewardCorrections[account] = magnifiedRewardCorrections[account].sub((magnifiedRewardPerShare.mul(value)).toInt256());
    }

    /**
     * Internal function that burns an amount of the token of a given account.
     *
     * Update magnifiedRewardCorrections to keep dividends unchanged.
     *
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint value) internal override {
        super._burn(account, value);

        magnifiedRewardCorrections[account] = magnifiedRewardCorrections[account].add((magnifiedRewardPerShare.mul(value)).toInt256());
    }
}
