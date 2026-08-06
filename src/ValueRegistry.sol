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

pragma solidity ^0.8.34;

/// @title An on-chain key/value registry for signed integer parameters
/// @notice Publicly readable data; mutating functions must be called by an authorized user
/// @dev The key naming convention is to add suffix with units, e.g., `_WAD`
contract ValueRegistry {
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

    // --- Structs ---
    /// @notice A registered value and its position in the keys array
    struct ValuePos {
        uint256 pos; // Position of the key in the keys array (keys[pos] == key)
        int256 val; // The value
    }

    /// @notice A key/value pair
    struct KeyValue {
        bytes32 key; // The parameter key (e.g., PARAM_WAD)
        int256 val; // The value
    }

    // --- Storage Variables ---
    /// @notice Mapping of admin addresses (can manage permissions)
    mapping(address usr => uint256 allowed) public wards;
    /// @notice Mapping of operator addresses (can manage key/value pairs)
    mapping(address usr => uint256 allowed) public buds;
    /// @notice Mapping of registered values
    mapping(bytes32 key => ValuePos value) internal values;
    /// @notice List of registered keys
    bytes32[] internal keys;

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

    /// @notice Set the value for one or more parameter keys
    /// @dev Later items win if the same key appears more than once in `items`
    /// @param _items The key/value pairs to set
    function setValues(KeyValue[] calldata _items) external toll {
        for (uint256 i; i < _items.length; i++) {
            _setValue(_items[i].key, _items[i].val);
        }
    }

    /// @notice Removes one or more keys from the keys list()
    /// @dev Removes each item from the array but moves the last element to its place
    /// @param _keys The keys to be removed
    function removeValues(bytes32[] calldata _keys) external toll {
        for (uint256 i; i < _keys.length; i++) {
            _removeValue(_keys[i]);
        }
    }

    // --- Internals ---

    /// @notice Set the value for a single parameter key
    /// @param _key The parameter key (e.g., PARAM_WAD)
    /// @param _val The value
    function _setValue(bytes32 _key, int256 _val) internal {
        if (count() > 0 && keys[values[_key].pos] == _key) {
            values[_key].val = _val; // Key exists in keys (update)
        } else {
            keys.push(_key);
            values[_key] = ValuePos({pos: count() - 1, val: _val});
        }
        emit SetValue(_key, _val);
    }

    /// @notice Removes a single key from the keys list()
    /// @param _key The key to be removed
    function _removeValue(bytes32 _key) internal {
        uint256 index = values[_key].pos; // Get position in the array
        require(count() > 0 && keys[index] == _key, "ValueRegistry/invalid-key");
        bytes32 move = keys[count() - 1]; // Get last key
        keys[index] = move; // Replace
        values[move].pos = index; // Update array pos
        keys.pop(); // Trim last key
        delete values[_key]; // Delete struct data

        emit RemoveValue(_key);
    }

    // --- Getters ---

    /// @notice Returns the number of keys being tracked in the keys array
    /// @return The number of keys
    function count() public view returns (uint256) {
        return keys.length;
    }

    /// @notice Returns the key and value of an item in the registry (for enumeration)
    /// @param _index The 0-based index into the underlying keys array
    /// @return The key and the value associated with it
    function get(uint256 _index) external view returns (bytes32, int256) {
        require(_index < count(), "ValueRegistry/index-out-of-bounds");
        return (keys[_index], values[keys[_index]].val);
    }

    /// @notice Returns the value for a particular key
    /// @param _key The parameter key (e.g., PARAM_WAD)
    /// @return val The value associated with the key
    function getValue(bytes32 _key) external view returns (int256 val) {
        require(count() > 0 && keys[values[_key].pos] == _key, "ValueRegistry/invalid-key");
        val = values[_key].val;
    }

    /// @return The list of keys being tracked by the registry
    function list() external view returns (bytes32[] memory) {
        return keys;
    }
}
