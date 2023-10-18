// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Contracts
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface ISsovV3 {
    function currentEpoch() external view returns (uint256 epoch);

    function getEpochTimes(
        uint256 epoch
    ) external view returns (uint256 start, uint256 end);
}

/// @title Volatility Engine
/// @author witherblock
/// @notice This contract stores the volatility of different tokens (token periods) for all Dopex Products
contract VolatilityEngine is AccessControl {
    /*==== PUBLIC VARS ====*/

    /// @dev Keeper Role
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /// @dev DEFAULT_HEARTBEAT of 60 minutes ensures that the volatility data does not remain stale with any new volatility tracking for any token(and token period)
    uint256 public constant DEFAULT_HEARTBEAT = 60 minutes;

    /// @dev SSOV address => id
    /// This mapping is required to allow the use of the deprecated getVolatility
    mapping(address => bytes32) public ssovToId;

    /// @dev id => heartbeat
    mapping(bytes32 => uint256) public heartbeats;

    /// @dev id => expiry => strike => Volatility
    mapping(bytes32 => mapping(uint256 => mapping(uint256 => Volatility)))
        public volatilities;

    /// @dev id => isFlatVolatility
    mapping(bytes32 => bool) public isFlatVolatility;

    /// @dev id => Volatility
    mapping(bytes32 => Volatility) public flatVolatilities;

    struct Volatility {
        /// @dev the volatility
        uint256 volatility;
        /// @dev last updated at timestamp
        uint256 lastUpdated;
    }

    /*==== EVENTS ====*/

    /// @notice The event is emitted on setting an ssov to an id
    /// @param id id
    /// @param ssov ssov
    event SetSsovToId(bytes32 id, address ssov);

    /// @notice The event is emitted on setting heartbeat for an id
    /// @param id id
    /// @param heartbeat heartbeat
    event SetHeartbeat(bytes32 id, uint256 heartbeat);

    /// @notice The event is emitted on setting if an id is using flat volatilities
    /// @param id id
    /// @param isFlatVolatility isFlatVolatility
    event SetIsFlatVolatility(bytes32 id, bool isFlatVolatility);

    /// @notice The event is emitted on updating of a volatility for an id
    /// @param id id
    /// @param expiry expiry
    /// @param strikes the strikes
    /// @param vols the volatilites
    event VolatilityUpdated(
        bytes32 id,
        uint256 expiry,
        uint256[] strikes,
        uint256[] vols
    );

    /// @notice The event is emitted on updating of a flat volatility for an id
    /// @param id id
    /// @param vol volatility
    event FlatVolatilityUpdated(bytes32 id, uint256 vol);

    /*==== ERRORS ====*/

    /// @notice Emitted if the heartbeat of a certain volatility is not met
    error HeartbeatNotFulfilled();

    /*==== CONSTRUCTOR ====*/

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*==== SETTER FUNCTIONS (ONLY ADMIN) ====*/

    /// @notice Set ssovs to an id
    /// @param _ssov ssov address
    /// @param _id id
    function setSsovToId(
        bytes32 _id,
        address _ssov
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ssovToId[_ssov] = _id;

        emit SetSsovToId(_id, _ssov);
    }

    /// @notice Set heartbeat for an id
    /// @param _id id
    /// @param _heartbeat heartbeat
    function setHeartbeat(
        bytes32 _id,
        uint256 _heartbeat
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        heartbeats[_id] = _heartbeat;

        emit SetHeartbeat(_id, _heartbeat);
    }

    /// @notice Set isFlatVolatility for an id
    /// @param _id id
    /// @param _isFlatVolatility isFlatVolatility
    function setIsFlatVolatility(
        bytes32 _id,
        bool _isFlatVolatility
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isFlatVolatility[_id] = _isFlatVolatility;

        emit SetIsFlatVolatility(_id, _isFlatVolatility);
    }

    /*==== KEEPER FUNCTIONS (ONLY KEEPER) ====*/

    /**
     * @notice Updates the volatility
     * @param _id id
     * @param _expiry expiry
     * @param _strikes strikes
     * @param _vols volatilities
     */
    function updateVolatility(
        bytes32 _id,
        uint256 _expiry,
        uint256[] memory _strikes,
        uint256[] memory _vols
    ) public onlyRole(KEEPER_ROLE) {
        require(_strikes.length == _vols.length, "Input lengths must match");
        require(
            !isFlatVolatility[_id],
            "Use updateFlatVolatility to update flat volatilities"
        );

        uint256 blockTimestamp = block.timestamp;
        uint256 strikesLength = _strikes.length;

        for (uint256 i; i < strikesLength; ) {
            require(_vols[i] > 0, "Volatility cannot be 0");
            volatilities[_id][_expiry][_strikes[i]] = Volatility({
                volatility: _vols[i],
                lastUpdated: blockTimestamp
            });

            unchecked {
                ++i;
            }
        }

        emit VolatilityUpdated(_id, _expiry, _strikes, _vols);
    }

    /**
     * @notice Batch updates the volatility
     * @param _ids ids
     * @param _expiries expiries
     * @param _strikes strikes
     * @param _vols volatilities
     */
    function batchUpdateVolatilities(
        bytes32[] memory _ids,
        uint256[] memory _expiries,
        uint256[][] memory _strikes,
        uint256[][] memory _vols
    ) external onlyRole(KEEPER_ROLE) {
        require(_ids.length == _expiries.length, "Input lengths must match");

        uint256 idsLength = _ids.length;

        for (uint256 i; i < idsLength; ) {
            updateVolatility(_ids[i], _expiries[i], _strikes[i], _vols[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Updates the volatility
     * @param _id id
     * @param _vol volatility
     */
    function updateFlatVolatility(
        bytes32 _id,
        uint256 _vol
    ) public onlyRole(KEEPER_ROLE) {
        require(
            isFlatVolatility[_id],
            "Use updateVolatility to update non flat volatilities"
        );

        flatVolatilities[_id] = Volatility({
            volatility: _vol,
            lastUpdated: block.timestamp
        });

        emit FlatVolatilityUpdated(_id, _vol);
    }

    /**
     * @notice Batch updates flat volatilities
     * @param _ids ids
     * @param _vols volatilities
     */
    function batchUpdateFlatVolatilities(
        bytes32[] memory _ids,
        uint256[] memory _vols
    ) public onlyRole(KEEPER_ROLE) {
        require(_ids.length == _vols.length, "Input lengths must match");

        uint256 idsLength = _ids.length;

        for (uint256 i; i < idsLength; ) {
            updateFlatVolatility(_ids[i], _vols[i]);

            unchecked {
                ++i;
            }
        }
    }

    /*==== VIEWS ====*/

    /**
     * @notice Gets the volatility of a strike
     * @param _id id
     * @param _expiry expiry
     * @param _strike strike
     * @return volatility
     */
    function getVolatility(
        bytes32 _id,
        uint256 _expiry,
        uint256 _strike
    ) external view returns (uint256) {
        Volatility memory vol;

        if (isFlatVolatility[_id]) {
            vol = flatVolatilities[_id];
        } else {
            vol = volatilities[_id][_expiry][_strike];
        }

        uint256 _heartbeat = heartbeats[_id] > 0
            ? heartbeats[_id]
            : DEFAULT_HEARTBEAT;

        if (block.timestamp > vol.lastUpdated + _heartbeat) {
            revert HeartbeatNotFulfilled();
        }

        return vol.volatility;
    }

    /**
     * @notice DEPRECATED Gets the volatility of a strike for an ssov
     * @param _strike strike
     * @return volatility
     */
    function getVolatility(uint256 _strike) external view returns (uint256) {
        bytes32 id = ssovToId[msg.sender];

        Volatility memory vol;

        if (isFlatVolatility[id]) {
            vol = flatVolatilities[id];
        } else {
            uint256 epoch = ISsovV3(msg.sender).currentEpoch();

            (, uint256 expiry) = ISsovV3(msg.sender).getEpochTimes(epoch);

            vol = volatilities[id][expiry][_strike];
        }

        uint256 _heartbeat = heartbeats[id] > 0
            ? heartbeats[id]
            : DEFAULT_HEARTBEAT;

        if (block.timestamp > vol.lastUpdated + _heartbeat) {
            revert HeartbeatNotFulfilled();
        }

        return vol.volatility;
    }
}
