// SPDX-FileCopyrightText: © 2026 Sky Ecosystem
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.34;

/// @title An on-chain registry for stUSDS rate calculation meta-parameters
/// @notice Publicly readable data; mutating functions must be called by an authorized user
/// @dev Values are signed integers; the convention is WAD scaling (1e18)
///      for all fractional parameters, e.g. OPT_UTIL_WAD = 0.9e18
contract ValueRegistry {
    // --- Structs ---
    /// @notice A registered value and its position in the keys array
    struct Value {
        uint256 pos; // 1 based position in the keys array; 0 means not present
        int256 val; // The value, WAD-scaled by convention
    }

    // --- Storage Variables ---
    /// @notice Mapping of admin addresses (can manage permissions)
    mapping(address => uint256) public wards;
    /// @notice Mapping of operator addresses (can manage key/value pairs)
    mapping(address => uint256) public buds;
    /// @notice Mapping of registered values
    mapping(bytes32 => Value) internal values;
    /// @notice List of registered keys
    bytes32[] internal keys;

    // --- Events ---
    /**
     * @notice `usr` was granted admin access.
     * @param usr The user address.
     */
    event Rely(address indexed usr);
    /**
     * @notice `usr` admin access was revoked.
     * @param usr The user address.
     */
    event Deny(address indexed usr);
    /**
     * @notice `usr` was granted operator access.
     * @param usr The user address.
     */
    event Kiss(address indexed usr);
    /**
     * @notice `usr` operator access was revoked.
     * @param usr The user address.
     */
    event Diss(address indexed usr);
    /**
     * @notice A value was set for a key.
     * @param key The parameter key.
     * @param val The new value.
     */
    event SetValue(bytes32 indexed key, int256 val);
    /**
     * @notice A key was removed from the registry.
     * @param key The removed parameter key.
     */
    event RemoveValue(bytes32 indexed key);

    // --- Modifiers ---
    modifier auth() {
        require(wards[msg.sender] == 1, "ValueRegistry/not-authorized");
        _;
    }

    modifier toll() {
        require(buds[msg.sender] == 1, "ValueRegistry/not-bud");
        _;
    }

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Administration ---
    /// @notice Grant authorization to an address
    /// @param usr The address to be authorized
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    /// @notice Revoke authorization from an address
    /// @param usr The address to be deauthorized
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    /// @notice Add an operator
    /// @param usr The address to add as an operator
    function kiss(address usr) external auth {
        buds[usr] = 1;
        emit Kiss(usr);
    }

    /// @notice Remove an operator
    /// @param usr The address to remove as an operator
    function diss(address usr) external auth {
        buds[usr] = 0;
        emit Diss(usr);
    }

    /// @notice Set the value for a parameter key
    /// @param key The parameter key (ex. OPT_UTIL_WAD)
    /// @param val The value, WAD-scaled by convention
    function setValue(bytes32 key, int256 val) external toll {
        Value storage value = values[key];
        if (value.pos == 0) {
            keys.push(key);
            value.pos = keys.length;
        }
        value.val = val;
        emit SetValue(key, val);
    }

    /// @notice Remove a key from the registry
    /// @param key The key to be removed
    function removeValue(bytes32 key) external toll {
        Value storage value = values[key];
        uint256 pos = value.pos;
        require(pos != 0, "ValueRegistry/invalid-key");

        bytes32 move = keys[keys.length - 1];
        if (move != key) {
            keys[pos - 1] = move;
            values[move].pos = pos;
        }
        keys.pop();
        delete values[key];
        emit RemoveValue(key);
    }

    // --- Getters ---
    /// @notice Returns the number of keys being tracked in the keys array
    /// @return The number of keys
    function count() external view returns (uint256) {
        return keys.length;
    }

    /// @notice Returns whether a value is set for a particular key
    /// @param key The parameter key (ex. OPT_UTIL_WAD)
    /// @return Whether the key is set
    function has(bytes32 key) external view returns (bool) {
        return values[key].pos != 0;
    }

    /// @notice Returns the key and value of an item in the registry (for enumeration)
    /// @param index The 0-based index into the underlying keys array
    /// @return The key and the value associated with it
    function get(uint256 index) external view returns (bytes32, int256) {
        require(index < keys.length, "ValueRegistry/index-out-of-bounds");
        return (keys[index], values[keys[index]].val);
    }

    /// @notice Returns the value for a particular key
    /// @param key The parameter key (ex. OPT_UTIL_WAD)
    /// @return val The value associated with the key
    function getValue(bytes32 key) external view returns (int256 val) {
        Value storage value = values[key];
        require(value.pos != 0, "ValueRegistry/invalid-key");
        val = value.val;
    }

    /// @return The list of keys being tracked by the registry
    function list() external view returns (bytes32[] memory) {
        return keys;
    }
}
