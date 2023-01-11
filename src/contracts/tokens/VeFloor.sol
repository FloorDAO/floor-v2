// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../authorities/AuthorityControl.sol';

import '../../interfaces/tokens/VeFloor.sol';


/**
 * A partial interface for our boosting calculator.
 */
interface IBoostedFloor {
    function updateFactor(address, uint256) external;
}


/**
 * The veFloor token is heavily influenced by the {VeJoeToken} token:
 * https://snowtrace.io/address/0x3cabf341943Bc8466245e4d6F1ae0f8D071a1456#code
 */
contract veFLOOR is AuthorityControl, IVeFLOOR {

    /// Monitor balances held by users
    mapping(address => uint256) private _balances;

    /// Hold the total token supply
    uint256 private _totalSupply;

    /// Metadata: Name
    string private _name;

    /// Metadata: Symbol
    string private _symbol;

    /// The BoostedFloor contract
    IBoostedFloor public boostedFloor;

    /// Emitted when `value` tokens are burned and minted
    event Burn(address indexed account, uint256 value);
    event Mint(address indexed beneficiary, uint256 value);

    /// ..
    event UpdateBoostedFloor(address indexed user, address boostedFloor);

    /**
     * Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * Both of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_, address _authority) AuthorityControl(_authority) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * Creates `_amount` token to `_to`. Must only be called by the owner (VeJoeStaking).
     *
     * @param _to The address that will receive the mint
     * @param _amount The amount to be minted
     */
    function mint(address _to, uint256 _amount) external onlyRole(FLOOR_MANAGER) {
        _mint(_to, _amount);
    }

    /**
     * Creates `amount` tokens and assigns them to `account`, increasing the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenOperation(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Mint(account, amount);

        _afterTokenOperation(account, _balances[account]);
    }

    /**
     * Destroys `_amount` tokens from `_from`. Callable only by the owner (VeJoeStaking).
     *
     * @param _from The address that will burn tokens
     * @param _amount The amount to be burned
     */
    function burnFrom(address _from, uint256 _amount) external onlyRole(FLOOR_MANAGER) {
        _burn(_from, _amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenOperation(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Burn(account, amount);

        _afterTokenOperation(account, _balances[account]);
    }

    /**
     * Sets the address of the master chef contract this updates.
     *
     * @param _boostedFloor the address of {BoostedFloor}
     */
    function setBoostedFloor(address _boostedFloor) external onlyRole(FLOOR_MANAGER) {
        // We allow 0 address here if we want to disable the callback operations
        boostedFloor = IBoostedFloor(_boostedFloor);
        emit UpdateBoostedFloor(msg.sender, _boostedFloor);
    }

    /**
     * Hook that is called before any minting and burning.
     *
     * @param from the account transferring tokens
     * @param to the account receiving tokens
     * @param amount the amount being minted or burned
     */
    function _beforeTokenOperation(address from, address to, uint256 amount) internal virtual {
        // Silence is golden.
    }

    /**
     * Hook that is called after any minting and burning.
     *
     * @param _account the account being affected
     * @param _newBalance the new balance of `account` after minting/burning
     */
    function _afterTokenOperation(address _account, uint256 _newBalance) internal {
        if (address(boostedFloor) != address(0)) {
            boostedFloor.updateFactor(_account, _newBalance);
        }
    }

}