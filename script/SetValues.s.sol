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

import {Script} from "forge-std/Script.sol";

import {ValueRegistry} from "../src/ValueRegistry.sol";

/// @title Set values on a deployed ValueRegistry
/// @notice Encodes each string key as `bytes32` and sets the values in a
///         single `setValues` batch; the broadcast account must be a bud
contract SetValues is Script {
    function run(ValueRegistry registry, string[] memory keys, int256[] memory vals) external {
        require(keys.length > 0, "SetValues/no-items");
        require(keys.length == vals.length, "SetValues/length-mismatch");

        ValueRegistry.KeyValue[] memory items = new ValueRegistry.KeyValue[](keys.length);
        for (uint256 i; i < keys.length; i++) {
            uint256 len = bytes(keys[i]).length;
            require(len > 0 && len <= 32, "SetValues/invalid-key");
            items[i] = ValueRegistry.KeyValue(bytes32(bytes(keys[i])), vals[i]);
        }

        vm.startBroadcast();
        registry.setValues(items);
        vm.stopBroadcast();
    }
}
