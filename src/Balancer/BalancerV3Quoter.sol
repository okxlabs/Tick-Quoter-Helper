// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


interface IERC20 {
    /// @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @dev Emitted when the allowance of a `spender` for an `owner` is set, where `value`
    /// is the new allowance.
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Moves `amount` tokens from the caller's account to `to`.
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Returns the remaining number of tokens that `spender` is allowed
    /// to spend on behalf of `owner`
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
    /// @dev Be aware of front-running risks: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Returns the decimals places of the token.
    function decimals() external view returns (uint8);
}

interface IWeightedPool {
    struct WeightedPoolDynamicData {
        uint256[] balancesLiveScaled18;
        uint256[] tokenRates;
        uint256 staticSwapFeePercentage;
        uint256 totalSupply;
        bool isPoolInitialized;
        bool isPoolPaused;
        bool isPoolInRecoveryMode;
    }

    struct WeightedPoolImmutableData {
        IERC20[] tokens;
        uint256[] decimalScalingFactors;
        uint256[] normalizedWeights;
    }

    function getWeightedPoolImmutableData()
        external
        view
        returns (WeightedPoolImmutableData memory data);

    function getWeightedPoolDynamicData()
        external
        view
        returns (WeightedPoolDynamicData memory data);
}

interface IStablePool {
    struct StablePoolDynamicData {
        uint256[] balancesLiveScaled18;
        uint256[] tokenRates;
        uint256 staticSwapFeePercentage;
        uint256 totalSupply;
        uint256 bptRate;
        uint256 amplificationParameter;
        uint256 startValue;
        uint256 endValue;
        uint32 startTime;
        uint32 endTime;
        bool isAmpUpdating;
        bool isPoolInitialized;
        bool isPoolPaused;
        bool isPoolInRecoveryMode;
    }

    struct StablePoolImmutableData {
        IERC20[] tokens;
        uint256[] decimalScalingFactors;
        uint256 amplificationParameterPrecision;
    }

    function getStablePoolDynamicData()
        external
        view
        returns (StablePoolDynamicData memory data);
    function getStablePoolImmutableData()
        external
        view
        returns (StablePoolImmutableData memory data);
}

interface IQuantAMMWeightedPool {
    struct QuantAMMWeightedPoolDynamicData {
        uint256[] balancesLiveScaled18;
        uint256[] tokenRates;
        uint256 totalSupply;
        bool isPoolInitialized;
        bool isPoolPaused;
        bool isPoolInRecoveryMode;
        int256[] firstFourWeightsAndMultipliers;
        int256[] secondFourWeightsAndMultipliers;
        uint40 lastUpdateTime;
        uint40 lastInteropTime;
    }

    struct QuantAMMWeightedPoolImmutableData {
        IERC20[] tokens;
        uint oracleStalenessThreshold;
        uint256 poolRegistry;
        int256[][] ruleParameters;
        uint64[] lambda;
        uint64 epsilonMax;
        uint64 absoluteWeightGuardRail;
        uint64 updateInterval;
        uint256 maxTradeSizeRatio;
    }

    function getQuantAMMWeightedPoolDynamicData() external view returns (QuantAMMWeightedPoolDynamicData memory data);
    function getQuantAMMWeightedPoolImmutableData() external view returns (QuantAMMWeightedPoolImmutableData memory data);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function getStaticSwapFeePercentage() external view returns (uint256 staticSwapFeePercentage);
}

interface IRateProvider {
    /**
     * @notice An 18 decimal fixed point number representing the exchange rate of one token to another related token.
     * @dev The meaning of this rate depends on the context. Note that there may be an error associated with a token
     * rate, and the caller might require a certain rounding direction to ensure correctness. This (legacy) interface
     * does not take a rounding direction or return an error, so great care must be taken when interpreting and using
     * rates in downstream computations.
     *
     * @return rate The current token rate
     */
    function getRate() external view returns (uint256 rate);
}

interface IVault {
    type PoolConfigBits is bytes32;

    enum TokenType {
        STANDARD,
        WITH_RATE
    }

    struct HooksConfig {
        bool enableHookAdjustedAmounts;
        bool shouldCallBeforeInitialize;
        bool shouldCallAfterInitialize;
        bool shouldCallComputeDynamicSwapFee;
        bool shouldCallBeforeSwap;
        bool shouldCallAfterSwap;
        bool shouldCallBeforeAddLiquidity;
        bool shouldCallAfterAddLiquidity;
        bool shouldCallBeforeRemoveLiquidity;
        bool shouldCallAfterRemoveLiquidity;
        address hooksContract;
    }

    struct TokenInfo {
        TokenType tokenType;
        IRateProvider rateProvider;
        bool paysYieldFees;
    }

    struct PoolData {
        PoolConfigBits poolConfigBits;
        IERC20[] tokens;
        TokenInfo[] tokenInfo;
        uint256[] balancesRaw;
        uint256[] balancesLiveScaled18;
        uint256[] tokenRates;
        uint256[] decimalScalingFactors;
    }

    function getHooksConfig(
        address pool
    ) external view returns (HooksConfig memory hooksConfig);

    function getPoolData(address pool) external view returns (PoolData memory);
}

interface IBalancerPool {
    function version() external view returns (string memory);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function getAmplificationParameter()
        external
        view
        returns (uint256 value, bool isUpdating, uint256 precision);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function getTokens() external view returns (IERC20[] memory tokens);
}

contract BalancerV3Quoter is Initializable, OwnableUpgradeable {
    struct WeightedPoolData {
        IWeightedPool.WeightedPoolImmutableData immutableData;
        IWeightedPool.WeightedPoolDynamicData dynamicData;
        IVault.HooksConfig hooksConfig;
    }

    struct StablePoolData {
        IStablePool.StablePoolImmutableData immutableData;
        IStablePool.StablePoolDynamicData dynamicData;
        IVault.HooksConfig hooksConfig;
    }

    address public constant VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    function initialize() public virtual initializer {
        __Ownable_init();
    }


    function getWeightedPoolData(
        address pool
    ) public view returns (WeightedPoolData memory data) {
        IWeightedPool.WeightedPoolImmutableData memory immutableData = IWeightedPool(pool).getWeightedPoolImmutableData();
        IWeightedPool.WeightedPoolDynamicData memory dynamicData = IWeightedPool(pool).getWeightedPoolDynamicData();
        IVault.HooksConfig memory hooksConfig = IVault(VAULT).getHooksConfig(pool);

        return (
            WeightedPoolData({
                immutableData: immutableData,
                dynamicData: dynamicData,
                hooksConfig: hooksConfig
            })
        );
    }

    function getStablePoolData(
        address pool
    ) public view returns (StablePoolData memory data) {
        IStablePool.StablePoolImmutableData memory immutableData = IStablePool(pool).getStablePoolImmutableData();
        IStablePool.StablePoolDynamicData memory dynamicData = IStablePool(pool).getStablePoolDynamicData();
        IVault.HooksConfig memory hooksConfig = IVault(VAULT).getHooksConfig(pool);

        return (
            StablePoolData({
                immutableData: immutableData,
                dynamicData: dynamicData,
                hooksConfig: hooksConfig
            })
        );
    }

    function getQuantAMMWeightedPoolDynamicData(
        address pool
    ) public view returns (IWeightedPool.WeightedPoolDynamicData memory data) {
        IQuantAMMWeightedPool.QuantAMMWeightedPoolDynamicData memory dynamicData = IQuantAMMWeightedPool(pool).getQuantAMMWeightedPoolDynamicData();
        uint256 staticSwapFeePercentage = IQuantAMMWeightedPool(pool).getStaticSwapFeePercentage();

        return (
            IWeightedPool.WeightedPoolDynamicData({
                balancesLiveScaled18: dynamicData.balancesLiveScaled18,
                tokenRates: dynamicData.tokenRates,
                staticSwapFeePercentage: staticSwapFeePercentage,
                totalSupply: dynamicData.totalSupply,
                isPoolInitialized: dynamicData.isPoolInitialized,
                isPoolPaused: dynamicData.isPoolPaused,
                isPoolInRecoveryMode: dynamicData.isPoolInRecoveryMode
            })
        );
    }

    function getQuantAMMWeightedPoolImmutableData(
        address pool
    ) public view returns (IWeightedPool.WeightedPoolImmutableData memory data) {
        IQuantAMMWeightedPool.QuantAMMWeightedPoolImmutableData memory immutableData = IQuantAMMWeightedPool(pool).getQuantAMMWeightedPoolImmutableData();
        IVault.PoolData memory poolData = IVault(VAULT).getPoolData(pool);
        uint256[] memory normalizedWeights = IQuantAMMWeightedPool(pool).getNormalizedWeights();

        return (
            IWeightedPool.WeightedPoolImmutableData({
                tokens: immutableData.tokens,
                decimalScalingFactors: poolData.decimalScalingFactors,
                normalizedWeights: normalizedWeights
            })
        );
    }

    function getQuantAMMWeightedPoolData(
        address pool
    ) public view returns (WeightedPoolData memory data) {
        IWeightedPool.WeightedPoolImmutableData memory immutableData = this.getQuantAMMWeightedPoolImmutableData(pool);
        IWeightedPool.WeightedPoolDynamicData memory dynamicData = this.getQuantAMMWeightedPoolDynamicData(pool);
        IVault.HooksConfig memory hooksConfig = IVault(VAULT).getHooksConfig(pool);

        return (
            WeightedPoolData({
                immutableData: immutableData,
                dynamicData: dynamicData,
                hooksConfig: hooksConfig
            })
        );
    }

    function getPoolData(
        address pool
    )
        public
        view
        virtual
        returns (
            string memory pool_type,
            WeightedPoolData memory weightedData,
            StablePoolData memory stableData,
            // IVault.PoolData memory poolData
            uint256[] memory balancesRaw
        )
    {
        pool_type = getPoolType(pool);
        if (contains(pool_type, "Others")) {
            return (pool_type, weightedData, stableData, balancesRaw);
        } else if (contains(pool_type, "QuantAMMWeighted")) {
            try this.getQuantAMMWeightedPoolData(pool) returns (WeightedPoolData memory _weightedData) {
                weightedData = _weightedData;
            } catch {
                pool_type = "Others";
            }
        } else if (contains(pool_type, "Weighted")) {
            try this.getWeightedPoolData(pool) returns (WeightedPoolData memory _weightedData) {
                weightedData = _weightedData;
            } catch {
                pool_type = "Others";
            }
        } else if (contains(pool_type, "Stable")) {
            try this.getStablePoolData(pool) returns (StablePoolData memory _stableData) {
                stableData = _stableData;
            } catch {
                pool_type = "Others";
            }
        }

        try IVault(VAULT).getPoolData(pool) returns (IVault.PoolData memory poolData) {
            balancesRaw = poolData.balancesRaw;
        } catch {
            // Return empty array as default
            balancesRaw = new uint256[](0);
        }
    }

    function getPoolType(
        address pool
    ) public view virtual returns (string memory pool_type) {
        try IBalancerPool(pool).version() returns (string memory _version) {
            if (contains(_version, "QuantAMMWeighted")) {
                return "QuantAMMWeighted";
            } else if (contains(_version, "Weighted")) {
                return "Weighted";
            } else if (contains(_version, "Stable")) {
                return "Stable";
            }
        } catch {
            // Ignore exception and proceed to the next check
        }

        try IBalancerPool(pool).getNormalizedWeights() {
            return "Weighted";
        } catch {
            // Ignore exception and return empty string
        }

        try IBalancerPool(pool).getAmplificationParameter() {
            return "Stable";
        } catch {
            // Ignore exception and return empty string
        }

        try IBalancerPool(pool).name() returns (string memory _name) {
            try IBalancerPool(pool).symbol() returns (string memory _symbol) {
                if (
                    contains(_name, "Stable") ||
                    contains(_name, "STABLE") ||
                    contains(_symbol, "Stable") ||
                    contains(_symbol, "STABLE")
                ) {
                    return "Stable";
                }
            } catch {
                // Ignore exception and proceed to the next check
            }
        } catch {
            // Ignore exception and proceed to the next check
        }

        return "Others";
    }

    function getHooksConfig(
        address pool
    ) public view virtual returns (IVault.HooksConfig memory hooksConfig) {
        return IVault(VAULT).getHooksConfig(pool);
    }

    function contains(
        string memory haystack,
        string memory needle
    ) internal pure virtual returns (bool) {
        return indexOf(haystack, needle) >= 0;
    }

    function getTokens(
        address pool
    ) public view returns (IERC20[] memory tokens) {
        return IBalancerPool(pool).getTokens();
    }

    function getTokenAddresses(
        address pool
    ) public view returns (address[] memory tokenAddresses) {
        IERC20[] memory tokens = getTokens(pool);
        tokenAddresses = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenAddresses[i] = address(tokens[i]);
        }
        return tokenAddresses;
    }

    function getTotalSupply(address pool) public view returns (uint256) {
        return IBalancerPool(pool).totalSupply();
    }

    function indexOf(
        string memory haystack,
        string memory needle
    ) internal pure virtual returns (int) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (
            needleBytes.length == 0 || haystackBytes.length < needleBytes.length
        ) {
            return -1;
        }

        for (uint i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return int(i);
            }
        }

        return -1;
    }
}