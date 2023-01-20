//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradable.sol";

// import '../interfaces/tokens/VaultXToken.sol';


/**
 * VaultXToken - (Based on Dividend Token)
 * @author Roger Wu (https://github.com/roger-wu)
 *
 * A mintable ERC20 token that allows anyone to pay and distribute a target token
 * to token holders as dividends and allows token holders to withdraw their dividends.
 */
contract VaultXToken is Initializable, ERC20, Ownable {

    IERC20 public target;

    // With `magnitude`, we can properly distribute dividends even if the amount of received
    // target is small. For more discussion about choosing the value of `magnitude`:
    // https://github.com/ethereum/EIPs/issues/1726#issuecomment-472352728
    uint256 constant internal magnitude = 2**128;
    uint256 internal magnifiedRewardPerShare;

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
    mapping(address => int256) internal magnifiedRewardCorrections;
    mapping(address => uint256) internal withdrawnRewards;

    /**
     *
     */
    function initialize(address vault, string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);
        target = _target;
    }

    /**
     * ..
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
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
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(
            amount,
            "ERC20: transfer amount exceeds allowance"
        ));

        return true;
    }

    function mint(address account, uint256 amount) public onlyOwner virtual {
        _mint(account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, without deducting from the caller's
     * allowance. Dangerous.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     */
    function burnFrom(address account, uint256 amount) public virtual onlyOwner {
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
     */
    function distributeRewards(uint amount) external virtual onlyOwner {
        require(totalSupply() != 0, "RewardDist: 0 supply");
        require(amount != 0, "RewardDist: 0 amount");

        // Because we receive the tokens from the staking contract, we assume the FLOOR tokens
        // have already been sent to the {RewardsLedger}.
        magnifiedRewardPerShare = magnifiedRewardPerShare.add((amount).mul(magnitude) / totalSupply());

        emit RewardsDistributed(msg.sender, amount);
    }

    /**
     * Withdraws the target distributed to the sender.
     *
     * @dev It emits a `RewardWithdrawn` event if the amount of withdrawn target is greater than 0.
     */
    function withdrawReward(address user) external onlyOwner {
        uint256 _withdrawableReward = withdrawableRewardOf(user);
        if (_withdrawableReward != 0) {
            withdrawnRewards[user] = withdrawnRewards[user].add(_withdrawableReward);

            // Withdraw FLOOR tokens from the rewards ledger and then stake them on behalf of
            // the user. This will give them veFloor tokens that they can choose to withdraw.
            target.safeTransferFrom(rewardsLedger, address(this), _withdrawableReward);
            target.approve(address(staking), _withdrawableReward);
            staking.depositFor(amount, msg.sender);

            emit RewardWithdrawn(user, _withdrawableReward);
        }
    }

    /**
     * View the amount of dividend in wei that an address can withdraw.
     *
     * @param _owner The address of a token holder.
     *
     * @return The amount of dividend in wei that `_owner` can withdraw.
     */
    function dividendOf(address _owner) public view returns(uint256) {
        return withdrawableRewardOf(_owner);
    }

    /**
     * View the amount of dividend in wei that an address can withdraw.
     *
     * @param _owner The address of a token holder.
     *
     * @return The amount of dividend in wei that `_owner` can withdraw.
     */
    function withdrawableRewardOf(address _owner) internal view returns(uint256) {
        return accumulativeRewardOf(_owner).sub(withdrawnRewards[_owner]);
    }

    /// @notice View the amount of dividend in wei that an address has withdrawn.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` has withdrawn.
    function withdrawnRewardOf(address _owner) public view returns(uint256) {
        return withdrawnRewards[_owner];
    }

    /// @notice View the amount of dividend in wei that an address has earned in total.
    /// @dev accumulativeRewardOf(_owner) = withdrawableRewardOf(_owner) + withdrawnRewardOf(_owner)
    /// = (magnifiedRewardPerShare * balanceOf(_owner) + magnifiedRewardCorrections[_owner]) / magnitude
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` has earned in total.
    function accumulativeRewardOf(address _owner) public view returns(uint256) {
        return magnifiedRewardPerShare.mul(balanceOf(_owner)).toInt256().add(magnifiedRewardCorrections[_owner]).toUint256Safe() / magnitude;
    }

    /// @dev Internal function that transfer tokens from one address to another.
    /// Update magnifiedRewardCorrections to keep dividends unchanged.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param value The amount to be transferred.
    function _transfer(address from, address to, uint256 value) internal override {
        super._transfer(from, to, value);

        int256 _magCorrection = magnifiedRewardPerShare.mul(value).toInt256();

        magnifiedRewardCorrections[from] = magnifiedRewardCorrections[from].add(_magCorrection);
        magnifiedRewardCorrections[to] = magnifiedRewardCorrections[to].sub(_magCorrection);
    }

    /// @dev Internal function that mints tokens to an account.
    /// Update magnifiedRewardCorrections to keep dividends unchanged.
    /// @param account The account that will receive the created tokens.
    /// @param value The amount that will be created.
    function _mint(address account, uint256 value) internal override {
        super._mint(account, value);
        magnifiedRewardCorrections[account] = magnifiedRewardCorrections[account].sub((magnifiedRewardPerShare.mul(value)).toInt256());
    }

    /// @dev Internal function that burns an amount of the token of a given account.
    /// Update magnifiedRewardCorrections to keep dividends unchanged.
    /// @param account The account whose tokens will be burnt.
    /// @param value The amount that will be burnt.
    function _burn(address account, uint256 value) internal override {
        super._burn(account, value);

        magnifiedRewardCorrections[account] = magnifiedRewardCorrections[account].add(
            (magnifiedRewardPerShare.mul(value)).toInt256()
        );
    }

    /// @dev This event MUST emit when target is distributed to token holders.
    /// @param from The address which sends target to this contract.
    /// @param weiAmount The amount of distributed target in wei.
    event RewardsDistributed(address indexed from, uint256 weiAmount);

    /// @dev This event MUST emit when an address withdraws their dividend.
    /// @param to The address which withdraws target from this contract.
    /// @param weiAmount The amount of withdrawn target in wei.
    event RewardWithdrawn(address indexed to, uint256 weiAmount);

}
