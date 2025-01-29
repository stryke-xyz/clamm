// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {AerodromeSingleTickLiquidityHandlerV2} from "../src/handlers/AerodromeSingleTickLiquidityHandlerV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {BoundedTTLHook_0Day} from "../src/handlers/hooks/BoundedTTLHook_0Day.sol";
import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract HandlerWhitelists is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factory = address(0);
        address sr = address(0);
        address positionManager = address(0);
        address zeroDayHook = address(0);
        address weeklyHook = address(0);
        address market = address(0);
        address primePool = address(0);
        address handler = address(0);
        address feeStrategy = address(0);

        vm.startBroadcast(deployerPrivateKey);
        vm.stopBroadcast();
    }

    function hookWhitelists(address _zeroday, address _weekly, address _optionMarket, address _handler) internal {
        BoundedTTLHook_0Day(_zeroday).updateWhitelistedAppsStatus(_optionMarket, true);
        BoundedTTLHook_0Day(_zeroday).updateWhitelistedAppsStatus(_handler, true);
        BoundedTTLHook_0Day(_weekly).updateWhitelistedAppsStatus(_optionMarket, true);
        BoundedTTLHook_0Day(_weekly).updateWhitelistedAppsStatus(_handler, true);
    }

    function handlerWhitelists(address _handler, address _positionManager) internal {
        AerodromeSingleTickLiquidityHandlerV2(_handler).updateWhitelistedApps(_positionManager, true);
    }

    function positionManagerWhitelists(address _positionManager, address _handler, address _app) internal {
        DopexV2PositionManager(_positionManager).updateWhitelistHandlerWithApp(_handler, _app, true);
        DopexV2PositionManager(_positionManager).updateWhitelistHandler(_handler, true);
    }

    function registerOptionMarketForFeeStrategy(address _feeStrategy, address _optionMarket) internal {
        DopexV2ClammFeeStrategyV2(_feeStrategy).registerOptionMarket(_optionMarket, 350000);
    }

    function optionMarketWhitelists(address _optionMarket, address _settler, address _pool) internal {
        DopexV2OptionMarketV2 market = DopexV2OptionMarketV2(_optionMarket);

        market.updateAddress(
            address(market.feeTo()),
            address(market.tokenURIFetcher()),
            address(market.dpFee()),
            address(market.optionPricing()),
            _settler,
            true,
            _pool,
            true
        );
    }
}
