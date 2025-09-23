// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

struct Params {
    // Price bounds (lower and upper). 0 < alpha < beta
    int256 alpha;
    int256 beta;
    // Rotation vector:
    // phi in (-90 degrees, 0] is the implicit rotation vector. It's stored as a point:
    int256 c; // c = cos(-phi) >= 0. rounded to 18 decimals
    int256 s; //  s = sin(-phi) >= 0. rounded to 18 decimals
    // Invariant: c^2 + s^2 == 1, i.e., the point (c, s) is normalized.
    // due to rounding, this may not = 1. The term dSq in DerivedParams corrects for this in extra precision

    // Stretching factor:
    int256 lambda; // lambda >= 1 where lambda == 1 is the circle.
}

struct DerivedParams {
    Vector2 tauAlpha;
    Vector2 tauBeta;
    int256 u; // from (A chi)_y = lambda * u + v
    int256 v; // from (A chi)_y = lambda * u + v
    int256 w; // from (A chi)_x = w / lambda + z
    int256 z; // from (A chi)_x = w / lambda + z
    int256 dSq; // error in c^2 + s^2 = dSq, used to correct errors in c, s, tau, u,v,w,z calculations
    //int256 dAlpha; // normalization constant for tau(alpha)
    //int256 dBeta; // normalization constant for tau(beta)
}

struct Vector2 {
    int256 x;
    int256 y;
}

interface IBalancerPool {
    function version() external view returns (string memory);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function getSwapFeePercentage() external view returns (uint256);
    function getPoolId() external view returns (bytes32);
    function getAmplificationParameter() external view returns (uint256 value, bool updating, uint256 precision);
    function getScalingFactors() external view returns (uint256[] memory);
    function getVirtualSupply() external view returns (uint256);
    function getTargets() external view returns (uint256 lowerTarget, uint256 upperTarget);
    function getBptIndex() external view returns (uint256);
    function getMainIndex() external view returns (uint256);
    function getWrappedIndex() external view returns (uint256);
    function getVault() external view returns (address);

    function getECLPParams() external view returns (Params memory params, DerivedParams memory d);
    function getGradualWeightUpdateParams() external view returns (uint256 startTime, uint256 endTime);
    function rateProvider0() external view returns (address);
    function rateProvider1() external view returns (address);
}

interface IVault {
    function getPoolTokens(bytes32 poolId) external view returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);
}

interface IRateProvider {
    function getRate() external view returns (uint256);
}

contract QueryBalancerV2Upgradeable is UUPSUpgradeable {
    address public owner;

    struct TokenInfo {
        uint256 balance;
        address tokenAddress;
        uint256 tokenIndex;
        uint256 weight; // 新增的权重字段
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Callable only by owner");
        _;
    }

    function initialize(address _owner) initializer public {
        owner = _owner;
    }

    function _authorizeUpgrade(address) internal override virtual onlyOwner {}

    function set_owner(address _owner) onlyOwner public {
        owner = _owner;
    }

    function get_pool_type(address pool) public view virtual returns (string memory pool_type) {
        try IBalancerPool(pool).version() returns (string memory _version) {
            if (contains(_version, "LinearPool")) {
                return "Linear";
            } else if (contains(_version, "ComposableStablePool")) {
                return "ComposableStable";
            } else if (contains(_version, "WeightedPool")) {
                return "Weighted";
            }
        } catch {
            // Ignore exception and proceed to the next check
        }

        try IBalancerPool(pool).getNormalizedWeights() {
            return "Weighted";
        } catch {
            // Ignore exception and return empty string
        }

        // New logic to check for Linear pool based on additional methods
        try IBalancerPool(pool).getTargets() {
            try IBalancerPool(pool).getWrappedIndex() {
                try IBalancerPool(pool).getScalingFactors() {
                    return "Linear";
                } catch {
                    // Ignore exception and proceed to the next check
                }
            } catch {
                // Ignore exception and proceed to the next check
            }
        } catch {
            // Ignore exception and proceed to the next check
        }

        try IBalancerPool(pool).getAmplificationParameter() {
            try IBalancerPool(pool).getBptIndex() {
                return "ComposableStable";
            } catch {
                // Ignore exception and proceed to the next check
            }
            return "Stable";
        } catch {
            // Ignore exception and return empty string
        }


        try IBalancerPool(pool).name() returns (string memory _name) {
            try IBalancerPool(pool).symbol() returns (string memory _symbol) {
                if (contains(_name, "Stable") || contains(_name, "STABLE") || contains(_symbol, "Stable") || contains(_symbol, "STABLE")) {
                    return "Stable";
                }
            } catch {
                // Ignore exception and proceed to the next check
            }
        } catch {
            // Ignore exception and proceed to the next check
        }


        return "";
    }

    function contains(string memory haystack, string memory needle) internal pure virtual returns (bool) {
        return indexOf(haystack, needle) >= 0;
    }

    // 查找子字符串的位置
    function indexOf(string memory haystack, string memory needle) internal pure virtual returns (int) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length == 0 || haystackBytes.length < needleBytes.length) {
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

    function get_params(address pool) public view virtual returns (
        uint256 blockNumber,
        uint256 fee,
        bytes32 poolId,
        TokenInfo[] memory tokenList,
        string memory subType,
        uint256 ampBps,
        uint256[] memory priceScale,
        uint256 liquidity,
        uint256 midFee,
        uint256 outFee,
        uint256[] memory coins
    ) {
        blockNumber = block.number;
        string memory poolType = get_pool_type(pool);

        // Common fields
        fee = IBalancerPool(pool).getSwapFeePercentage();
        poolId = IBalancerPool(pool).getPoolId();
        (address[] memory tokens, uint256[] memory balances,) = IVault(IBalancerPool(pool).getVault()).getPoolTokens(poolId);

        // Prepare token list
        tokenList = new TokenInfo[](tokens.length);
        uint256[] memory weights;
        if (keccak256(bytes(poolType)) == keccak256(bytes("Weighted"))) {
            weights = IBalancerPool(pool).getNormalizedWeights();
        }

        for (uint i = 0; i < tokens.length; i++) {
            tokenList[i] = TokenInfo({
                balance: balances[i],
                tokenAddress: tokens[i],
                tokenIndex: i,
                weight: weights.length > 0 ? weights[i] : 0 // 如果有权重则赋值，否则为0
            });
        }

        subType = poolType;

        // Specific fields based on pool type
        if (keccak256(bytes(poolType)) == keccak256(bytes("Stable")) || keccak256(bytes(poolType)) == keccak256(bytes("ComposableStable"))) {
            (uint256 value,, uint256 precision) = IBalancerPool(pool).getAmplificationParameter();
            ampBps = value / precision;
            try IBalancerPool(pool).getScalingFactors() returns (uint256[] memory scalingFactors) {
                priceScale = scalingFactors;
            } catch {
                priceScale = new uint256[](0); // 默认值
            }
        } else if (keccak256(bytes(poolType)) == keccak256(bytes("Linear"))) {
            liquidity = IBalancerPool(pool).getVirtualSupply();
            (midFee, outFee) = IBalancerPool(pool).getTargets();
            try IBalancerPool(pool).getScalingFactors() returns (uint256[] memory scalingFactors) {
                priceScale = scalingFactors;
            } catch {
                priceScale = new uint256[](0); // 默认值
            }
            uint256 bptIndex = IBalancerPool(pool).getBptIndex();
            uint256 mainIndex = IBalancerPool(pool).getMainIndex();
            uint256 wrappedIndex = IBalancerPool(pool).getWrappedIndex();

            coins = new uint256[](3);
            coins[0] = bptIndex;
            coins[1] = mainIndex;
            coins[2] = wrappedIndex;
        }
    }
}

contract QueryBalancerV2UpgradeableV2 is QueryBalancerV2Upgradeable {
    function get_pool_type(address pool) public view virtual override returns (string memory pool_type) {
        try IBalancerPool(pool).version() returns (string memory _version) {
            if (contains(_version, "LinearPool")) {
                return "Linear";
            } else if (contains(_version, "ComposableStablePool")) {
                return "ComposableStable";
            } else if (contains(_version, "WeightedPool")) {
                return "Weighted";
            }
        } catch {
            // Ignore exception and proceed to the next check
        }

        try IBalancerPool(pool).getECLPParams() {
            return "GyroECLP";
        } catch {
            // Ignore exception and return empty string
        }

        try IBalancerPool(pool).getNormalizedWeights() {
            try IBalancerPool(pool).getGradualWeightUpdateParams() returns (uint256 startTime, uint256 endTime) {
                if (startTime < block.timestamp && endTime > block.timestamp) {
                    // LiquidityBootstrappingPool暂不支持
                    return "";
                }
            } catch {
                // Ignore exception and return empty string
            }
            return "Weighted";
        } catch {
            // Ignore exception and return empty string
        }

        // New logic to check for Linear pool based on additional methods
        try IBalancerPool(pool).getTargets() {
            try IBalancerPool(pool).getWrappedIndex() {
                try IBalancerPool(pool).getScalingFactors() {
                    return "Linear";
                } catch {
                    // Ignore exception and proceed to the next check
                }
            } catch {
                // Ignore exception and proceed to the next check
            }
        } catch {
            // Ignore exception and proceed to the next check
        }

        try IBalancerPool(pool).getAmplificationParameter() {
            try IBalancerPool(pool).getBptIndex() {
                return "ComposableStable";
            } catch {
                // Ignore exception and proceed to the next check
            }
            return "Stable";
        } catch {
            // Ignore exception and return empty string
        }


        try IBalancerPool(pool).name() returns (string memory _name) {
            try IBalancerPool(pool).symbol() returns (string memory _symbol) {
                if (contains(_name, "Stable") || contains(_name, "STABLE") || contains(_symbol, "Stable") || contains(_symbol, "STABLE")) {
                    return "Stable";
                }
            } catch {
                // Ignore exception and proceed to the next check
            }
        } catch {
            // Ignore exception and proceed to the next check
        }


        return "";
    }
}

struct FXPoolData {
    address poolAddress;
    bytes32 poolId;
}

interface IFXPoolFactory {
    function getFxPools(address[] memory _assets) external view returns (FXPoolData[] memory);
}

interface IFXPoolDeployer {
    function getFXPoolDetails(
        address _fxpoolAddr
    )
        external
        view
        returns (
            string memory name,
            address baseToken,
            address baseOracle,
            uint256 protocolPercentFee,
            uint256 liquidity,
            uint256 alpha,
            uint256 beta,
            uint256 delta,
            uint256 epsilon,
            uint256 lambda
        );
}

contract QueryBalancerV2UpgradeableV3 is QueryBalancerV2UpgradeableV2 {

    function get_pool_type(address pool) public view virtual override returns (string memory pool_type) {
        // Call the base class's get_pool_type method
        pool_type = super.get_pool_type(pool);

        if (bytes(pool_type).length == 0) {
            try this.is_xave(pool) returns (bool isXave) {
                if (isXave) {
                    return "Xave";
                }
            } catch {
                // Ignore exception and proceed to the next check
            }
        }

        return pool_type;
    }

    function fx_pool_factory() public view virtual returns (address) {
    }

    function fx_pool_deployer() public view virtual returns (address) {
    }

    function is_xave(address pool) public view virtual returns (bool) {
        bytes32 poolId = IBalancerPool(pool).getPoolId();
        (address[] memory tokens, ,) = IVault(IBalancerPool(pool).getVault()).getPoolTokens(poolId);
        if (tokens.length == 2) {
            FXPoolData[] memory fxPools = IFXPoolFactory(fx_pool_factory()).getFxPools(tokens);
        
            for (uint i = 0; i < fxPools.length; i++) {
                if (fxPools[i].poolAddress == pool) {
                    return true;
                }
            }
        }

        try IFXPoolDeployer(fx_pool_deployer()).getFXPoolDetails(pool) returns (string memory, address, address, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
            return true;
        } catch {
            // Ignore exception and proceed to the next check
        }

        return false;
    }

    function get_params_v2(address pool) public view virtual returns (
        uint256 blockNumber,
        uint256 fee,
        bytes32 poolId,
        TokenInfo[] memory tokenList,
        string memory subType,
        uint256 ampBps,
        uint256[] memory priceScale,
        uint256 liquidity,
        uint256 midFee,
        uint256 outFee,
        uint256[] memory coins,
        uint256 vReserve0,
        uint256 vReserve1,
        int256[] memory eclpParams
    ) {
        blockNumber = block.number;
        string memory poolType = get_pool_type(pool);

        // Common fields
        fee = IBalancerPool(pool).getSwapFeePercentage();
        poolId = IBalancerPool(pool).getPoolId();
        (address[] memory tokens, uint256[] memory balances,) = IVault(IBalancerPool(pool).getVault()).getPoolTokens(poolId);

        // Prepare token list
        tokenList = new TokenInfo[](tokens.length);
        uint256[] memory weights;
        if (keccak256(bytes(poolType)) == keccak256(bytes("Weighted"))) {
            weights = IBalancerPool(pool).getNormalizedWeights();
        }

        for (uint i = 0; i < tokens.length; i++) {
            tokenList[i] = TokenInfo({
                balance: balances[i],
                tokenAddress: tokens[i],
                tokenIndex: i,
                weight: weights.length > 0 ? weights[i] : 0 // 如果有权重则赋值，否则为0
            });
        }

        subType = poolType;

        // Specific fields based on pool type
        if (keccak256(bytes(poolType)) == keccak256(bytes("Stable")) || keccak256(bytes(poolType)) == keccak256(bytes("ComposableStable"))) {
            (uint256 value,, uint256 precision) = IBalancerPool(pool).getAmplificationParameter();
            ampBps = value / precision;
            try IBalancerPool(pool).getScalingFactors() returns (uint256[] memory scalingFactors) {
                priceScale = scalingFactors;
            } catch {
                priceScale = new uint256[](0); // 默认值
            }
        } else if (keccak256(bytes(poolType)) == keccak256(bytes("Linear"))) {
            liquidity = IBalancerPool(pool).getVirtualSupply();
            (midFee, outFee) = IBalancerPool(pool).getTargets();
            try IBalancerPool(pool).getScalingFactors() returns (uint256[] memory scalingFactors) {
                priceScale = scalingFactors;
            } catch {
                priceScale = new uint256[](0); // 默认值
            }
            uint256 bptIndex = IBalancerPool(pool).getBptIndex();
            uint256 mainIndex = IBalancerPool(pool).getMainIndex();
            uint256 wrappedIndex = IBalancerPool(pool).getWrappedIndex();

            coins = new uint256[](3);
            coins[0] = bptIndex;
            coins[1] = mainIndex;
            coins[2] = wrappedIndex;
        } else if (keccak256(bytes(poolType)) == keccak256(bytes("GyroECLP"))) {
            address rateProvider0 = IBalancerPool(pool).rateProvider0();
            if (rateProvider0 != address(0)) {
                vReserve0 = IRateProvider(rateProvider0).getRate();
            }
            address rateProvider1 = IBalancerPool(pool).rateProvider1();
            if (rateProvider1 != address(0)) {
                vReserve1 = IRateProvider(rateProvider1).getRate();
            }

            (Params memory params, DerivedParams memory d) = IBalancerPool(pool).getECLPParams();
            eclpParams = new int256[](14);
            // Flatten Params fields into priceScale
            eclpParams[0] = params.alpha;
            eclpParams[1] = params.beta;
            eclpParams[2] = params.c;
            eclpParams[3] = params.s;
            eclpParams[4] = params.lambda;

            // Flatten DerivedParams fields into priceScale
            eclpParams[5] = d.tauAlpha.x;
            eclpParams[6] = d.tauAlpha.y;
            eclpParams[7] = d.tauBeta.x;
            eclpParams[8] = d.tauBeta.y;
            eclpParams[9] = d.u;
            eclpParams[10] = d.v;
            eclpParams[11] = d.w;
            eclpParams[12] = d.z;
            eclpParams[13] = d.dSq;
        }
    }
}

contract QueryBalancerV2UpgradeableAvalanche is QueryBalancerV2UpgradeableV3 {
    function fx_pool_factory() public view virtual override returns (address) {
        return 0x81fE9e5B28dA92aE949b705DfDB225f7a7cc5134;
    }

    function fx_pool_deployer() public view virtual override returns (address) {
        return 0x4042dC4110Ea9500338737605A60065c3de152C6;
    }

}

contract QueryBalancerV2UpgradeablePolygon is QueryBalancerV2UpgradeableV3 {
    function fx_pool_factory() public view virtual override returns (address) {
        return 0x627D759314D5c4007b461A74eBaFA7EBC5dFeD71;
    }

    function fx_pool_deployer() public view virtual override returns (address) {
        return 0xF169c1Ae8De24Da43a3dC5c5F05De412b4848bD3;
    }

}

contract QueryBalancerV2UpgradeableEth is QueryBalancerV2UpgradeableV3 {
    function fx_pool_factory() public view virtual override returns (address) {
        return 0x81fE9e5B28dA92aE949b705DfDB225f7a7cc5134;
    }

    function fx_pool_deployer() public view virtual override returns (address) {
        return 0xfb23Bc0D2629268442CD6521CF4170698967105f;
    }

}