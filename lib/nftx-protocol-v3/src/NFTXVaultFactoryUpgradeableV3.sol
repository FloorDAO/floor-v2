// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// inheriting
import {UpgradeableBeacon} from "@src/custom/proxy/UpgradeableBeacon.sol";
import {PausableUpgradeable} from "@src/custom/PausableUpgradeable.sol";

// libs
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {ExponentialPremium} from "@src/lib/ExponentialPremium.sol";
import {Create2Upgradeable} from "@openzeppelin-upgradeable/contracts/utils/Create2Upgradeable.sol";

// contracts
import {Create2BeaconProxy} from "@src/custom/proxy/Create2BeaconProxy.sol";
import {NFTXVaultUpgradeableV3} from "@src/NFTXVaultUpgradeableV3.sol";

// interfaces
import {INFTXVaultV3} from "@src/interfaces/INFTXVaultV3.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolDerivedState} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol";

import {INFTXVaultFactoryV3} from "@src/interfaces/INFTXVaultFactoryV3.sol";

// Authors: @0xKiwi_, @alexgausman and @apoorvlathey

contract NFTXVaultFactoryUpgradeableV3 is
    INFTXVaultFactoryV3,
    PausableUpgradeable,
    UpgradeableBeacon
{
    // =============================================================
    //                            CONSTANTS
    // =============================================================
    uint256 constant MAX_DEPOSITOR_PREMIUM_SHARE = 1 ether;
    bytes internal constant BEACON_CODE = type(Create2BeaconProxy).creationCode;

    // =============================================================
    //                            VARIABLES
    // =============================================================

    address public override feeDistributor;
    address public override eligibilityManager;

    mapping(address => address[]) internal _vaultsForAsset;

    address[] internal _vaults;

    mapping(address => bool) public override excludedFromFees;

    mapping(uint256 => VaultFees) internal _vaultFees;

    uint64 public override factoryMintFee;
    uint64 public override factoryRedeemFee;
    uint64 public override factorySwapFee;

    uint32 public override twapInterval;
    // time during which a deposited tokenId incurs premium during withdrawal from the vault
    uint256 public override premiumDuration;
    // max premium value in vTokens when NFT just deposited
    uint256 public override premiumMax;
    // fraction in wei, what portion of the premium to send to the NFT depositor
    uint256 public override depositorPremiumShare;

    // =============================================================
    //                           INIT
    // =============================================================

    function __NFTXVaultFactory_init(
        address vaultImpl,
        uint32 twapInterval_,
        uint256 premiumDuration_,
        uint256 premiumMax_,
        uint256 depositorPremiumShare_
    ) public override initializer {
        __Pausable_init();
        // We use a beacon proxy so that every child contract follows the same implementation code.
        __UpgradeableBeacon__init(vaultImpl);
        setFactoryFees(0.1 ether, 0.1 ether, 0.1 ether);

        if (twapInterval_ == 0) revert ZeroTwapInterval();
        if (depositorPremiumShare_ > MAX_DEPOSITOR_PREMIUM_SHARE)
            revert DepositorPremiumShareExceedsLimit();

        twapInterval = twapInterval_;
        premiumDuration = premiumDuration_;
        premiumMax = premiumMax_;
        depositorPremiumShare = depositorPremiumShare_;
    }

    // =============================================================
    //                     PUBLIC / EXTERNAL WRITE
    // =============================================================

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function createVault(
        string memory name,
        string memory symbol,
        address assetAddress,
        bool is1155,
        bool allowAllItems
    ) external override returns (uint256 vaultId) {
        onlyOwnerIfPaused(0);

        if (feeDistributor == address(0)) revert FeeDistributorNotSet();
        if (implementation() == address(0)) revert VaultImplementationNotSet();

        address vaultAddr = _deployVault(
            name,
            symbol,
            assetAddress,
            is1155,
            allowAllItems
        );

        vaultId = _vaults.length;
        _vaultsForAsset[assetAddress].push(vaultAddr);
        _vaults.push(vaultAddr);

        emit NewVault(vaultId, vaultAddr, assetAddress, name, symbol);
    }

    // =============================================================
    //                     ONLY PRIVILEGED WRITE
    // =============================================================

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setFactoryFees(
        uint256 mintFee,
        uint256 redeemFee,
        uint256 swapFee
    ) public override onlyOwner {
        if (mintFee > 0.5 ether) revert FeeExceedsLimit();
        if (redeemFee > 0.5 ether) revert FeeExceedsLimit();
        if (swapFee > 0.5 ether) revert FeeExceedsLimit();

        factoryMintFee = uint64(mintFee);
        factoryRedeemFee = uint64(redeemFee);
        factorySwapFee = uint64(swapFee);

        emit UpdateFactoryFees(mintFee, redeemFee, swapFee);
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setVaultFees(
        uint256 vaultId,
        uint256 mintFee,
        uint256 redeemFee,
        uint256 swapFee
    ) external override {
        if (msg.sender != owner()) {
            address vaultAddr = _vaults[vaultId];
            if (msg.sender != vaultAddr) revert CallerIsNotVault();
        }
        if (mintFee > 0.5 ether) revert FeeExceedsLimit();
        if (redeemFee > 0.5 ether) revert FeeExceedsLimit();
        if (swapFee > 0.5 ether) revert FeeExceedsLimit();

        _vaultFees[vaultId] = VaultFees(
            true,
            uint64(mintFee),
            uint64(redeemFee),
            uint64(swapFee)
        );
        emit UpdateVaultFees(vaultId, mintFee, redeemFee, swapFee);
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function disableVaultFees(uint256 vaultId) external override {
        if (msg.sender != owner()) {
            address vaultAddr = _vaults[vaultId];
            if (msg.sender != vaultAddr) revert CallerIsNotVault();
        }
        delete _vaultFees[vaultId];
        emit DisableVaultFees(vaultId);
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setFeeDistributor(
        address feeDistributor_
    ) external override onlyOwner {
        if (feeDistributor_ == address(0)) revert ZeroAddress();

        emit NewFeeDistributor(feeDistributor, feeDistributor_);
        feeDistributor = feeDistributor_;
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setFeeExclusion(
        address excludedAddr,
        bool excluded
    ) external override onlyOwner {
        excludedFromFees[excludedAddr] = excluded;
        emit FeeExclusion(excludedAddr, excluded);
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setEligibilityManager(
        address eligibilityManager_
    ) external override onlyOwner {
        emit NewEligibilityManager(eligibilityManager, eligibilityManager_);
        eligibilityManager = eligibilityManager_;
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setTwapInterval(uint32 twapInterval_) external override onlyOwner {
        if (twapInterval_ == 0) revert ZeroTwapInterval();

        twapInterval = twapInterval_;

        emit NewTwapInterval(twapInterval_);
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setPremiumDuration(
        uint256 premiumDuration_
    ) external override onlyOwner {
        premiumDuration = premiumDuration_;

        emit NewPremiumDuration(premiumDuration_);
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setPremiumMax(uint256 premiumMax_) external override onlyOwner {
        premiumMax = premiumMax_;

        emit NewPremiumMax(premiumMax_);
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function setDepositorPremiumShare(
        uint256 depositorPremiumShare_
    ) external override onlyOwner {
        if (depositorPremiumShare_ > MAX_DEPOSITOR_PREMIUM_SHARE)
            revert DepositorPremiumShareExceedsLimit();

        depositorPremiumShare = depositorPremiumShare_;

        emit NewDepositorPremiumShare(depositorPremiumShare_);
    }

    // =============================================================
    //                     PUBLIC / EXTERNAL VIEW
    // =============================================================

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function vaultFees(
        uint256 vaultId
    )
        external
        view
        override
        returns (uint256 mintFee, uint256 redeemFee, uint256 swapFee)
    {
        VaultFees memory fees = _vaultFees[vaultId];
        if (fees.active) {
            return (
                uint256(fees.mintFee),
                uint256(fees.redeemFee),
                uint256(fees.swapFee)
            );
        }

        return (
            uint256(factoryMintFee),
            uint256(factoryRedeemFee),
            uint256(factorySwapFee)
        );
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function getVTokenPremium721(
        uint256 vaultId,
        uint256 tokenId
    ) external view override returns (uint256 premium, address depositor) {
        INFTXVaultV3 _vault = INFTXVaultV3(_vaults[vaultId]);

        if (_vault.holdingsContains(tokenId)) {
            uint48 timestamp;
            (timestamp, depositor) = _vault.tokenDepositInfo(tokenId);

            premium = _getVTokenPremium(timestamp, premiumMax, premiumDuration);
        }
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function getVTokenPremium1155(
        uint256 vaultId,
        uint256 tokenId,
        uint256 amount
    )
        external
        view
        override
        returns (
            uint256 totalPremium,
            uint256[] memory premiums,
            address[] memory depositors
        )
    {
        INFTXVaultV3 _vault = INFTXVaultV3(_vaults[vaultId]);

        if (_vault.holdingsContains(tokenId)) {
            if (amount == 0) revert ZeroAmountRequested();

            // max possible array lengths
            premiums = new uint256[](amount);
            depositors = new address[](amount);

            uint256 _pointerIndex1155 = _vault.pointerIndex1155(tokenId);

            uint256 i = 0;
            // cache
            uint256 _premiumMax = premiumMax;
            uint256 _premiumDuration = premiumDuration;
            uint256 _tokenPositionLength = _vault.depositInfo1155Length(
                tokenId
            );
            while (true) {
                if (_tokenPositionLength <= _pointerIndex1155 + i)
                    revert NFTInventoryExceeded();

                (uint256 qty, address depositor, uint48 timestamp) = _vault
                    .depositInfo1155(tokenId, _pointerIndex1155 + i);

                if (qty > amount) {
                    uint256 vTokenPremium = _getVTokenPremium(
                        timestamp,
                        _premiumMax,
                        _premiumDuration
                    ) * amount;
                    totalPremium += vTokenPremium;

                    premiums[i] = vTokenPremium;
                    depositors[i] = depositor;

                    // end loop
                    break;
                } else {
                    amount -= qty;

                    uint256 vTokenPremium = _getVTokenPremium(
                        timestamp,
                        _premiumMax,
                        _premiumDuration
                    ) * qty;
                    totalPremium += vTokenPremium;

                    premiums[i] = vTokenPremium;
                    depositors[i] = depositor;

                    unchecked {
                        ++i;
                    }
                }
            }

            uint256 finalArrayLength = i + 1;

            if (finalArrayLength < premiums.length) {
                // change array length
                assembly {
                    mstore(premiums, finalArrayLength)
                    mstore(depositors, finalArrayLength)
                }
            }
        }
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function isLocked(uint256 lockId) external view override returns (bool) {
        return isPaused[lockId];
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function vaultsForAsset(
        address assetAddress
    ) external view override returns (address[] memory) {
        return _vaultsForAsset[assetAddress];
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function allVaults() external view override returns (address[] memory) {
        return _vaults;
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function numVaults() external view override returns (uint256) {
        return _vaults.length;
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function vault(uint256 vaultId) external view override returns (address) {
        return _vaults[vaultId];
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function computeVaultAddress(
        address assetAddress,
        string memory name,
        string memory symbol
    ) external view returns (address) {
        return
            Create2Upgradeable.computeAddress(
                keccak256(abi.encode(assetAddress, name, symbol)),
                keccak256(BEACON_CODE)
            );
    }

    /**
     * @inheritdoc INFTXVaultFactoryV3
     */
    function getTwapX96(
        address pool
    ) external view override returns (uint256 priceX96) {
        // secondsAgos[0] (from [before]) -> secondsAgos[1] (to [now])
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = 0;

        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSelector(
                IUniswapV3PoolDerivedState.observe.selector,
                secondsAgos
            )
        );

        // observe might fail for newly created pools that don't have sufficient observations yet
        if (!success) {
            // observations = [0, 1, 2, ..., index, (index + 1), ..., (cardinality - 1)]
            // Case 1: if entire array initialized once, then oldest observation at (index + 1) % cardinality
            // Case 2: array only initialized till index, then oldest obseravtion at index 0

            // Check Case 1
            (, , uint16 index, uint16 cardinality, , , ) = IUniswapV3Pool(pool)
                .slot0();

            (
                uint32 oldestAvailableTimestamp,
                ,
                ,
                bool initialized
            ) = IUniswapV3Pool(pool).observations((index + 1) % cardinality);

            // Case 2
            if (!initialized)
                (oldestAvailableTimestamp, , , ) = IUniswapV3Pool(pool)
                    .observations(0);

            // get corresponding observation
            secondsAgos[0] = uint32(block.timestamp - oldestAvailableTimestamp);
            (success, data) = pool.staticcall(
                abi.encodeWithSelector(
                    IUniswapV3PoolDerivedState.observe.selector,
                    secondsAgos
                )
            );
            // might revert if oldestAvailableTimestamp == block.timestamp, so we return price as 0
            if (!success || secondsAgos[0] == 0) {
                return 0;
            }
        }

        int56[] memory tickCumulatives = abi.decode(data, (int56[])); // don't bother decoding the liquidityCumulatives array

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24(
                (tickCumulatives[1] - tickCumulatives[0]) /
                    int56(int32(secondsAgos[0]))
            )
        );
        priceX96 = FullMath.mulDiv(
            sqrtPriceX96,
            sqrtPriceX96,
            FixedPoint96.Q96
        );
    }

    // =============================================================
    //                        INTERNAL HELPERS
    // =============================================================

    function _deployVault(
        string memory name,
        string memory symbol,
        address assetAddress,
        bool is1155,
        bool allowAllItems
    ) internal returns (address) {
        address newBeaconProxy = Create2Upgradeable.deploy(
            0,
            keccak256(abi.encode(assetAddress, name, symbol)),
            BEACON_CODE
        );
        NFTXVaultUpgradeableV3(newBeaconProxy).__NFTXVault_init(
            name,
            symbol,
            assetAddress,
            is1155,
            allowAllItems
        );
        // Manager for configuration.
        NFTXVaultUpgradeableV3(newBeaconProxy).setManager(msg.sender);
        // Owner for administrative functions.
        NFTXVaultUpgradeableV3(newBeaconProxy).transferOwnership(owner());
        return newBeaconProxy;
    }

    function _getVTokenPremium(
        uint48 timestamp,
        uint256 _premiumMax,
        uint256 _premiumDuration
    ) internal view returns (uint256) {
        return
            ExponentialPremium.getPremium(
                timestamp,
                _premiumMax,
                _premiumDuration
            );
    }
}
