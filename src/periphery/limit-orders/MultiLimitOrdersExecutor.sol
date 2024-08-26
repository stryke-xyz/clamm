// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

// Interfaces
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ILimitOrders} from "../../interfaces/ILimitOrders.sol";
import {IOptionMarket} from "../../interfaces/IOptionMarket.sol";

// Contracts
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

// Libraries
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// @dev A contract simulate or execute multi exercises
contract MultiLimitOrdersExecutor is Multicall {
    using SafeERC20 for IERC20;

    address public owner;

    struct LimitOrderExecutionParams {
        ILimitOrders handler;
        ILimitOrders.Order order;
        ILimitOrders.Signature signature;
        ILimitOrders.ExerciseOptionsSwapData swapData;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function setOwner(address _newOwner) external {
        require(msg.sender == owner);
        owner = _newOwner;
    }

    function withdraw(IERC20 token) external {
        require(msg.sender == owner);
        token.safeTransfer(owner, token.balanceOf(address(this)));
    }

    function multiExercise(LimitOrderExecutionParams[] calldata _params)
        external
        returns (uint256[] memory comissions)
    {
        require(msg.sender == owner, "Not owner");
        comissions = new uint256[](_params.length);

        for (uint256 i; i < _params.length;) {
            try _params[i].handler.exerciseOption(_params[i].order, _params[i].signature, _params[i].swapData) returns (
                uint256 comission
            ) {
                comissions[i] = comission;
            } catch {}
            unchecked {
                ++i;
            }
        }
    }
}
