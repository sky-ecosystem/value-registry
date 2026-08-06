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

import {Test} from "forge-std/Test.sol";

import {SetValues} from "../script/SetValues.s.sol";
import {ValueRegistry} from "../src/ValueRegistry.sol";

contract SetValuesTest is Test {
    SetValues script;
    ValueRegistry registry;

    function setUp() public {
        script = new SetValues();
        registry = new ValueRegistry();

        // Discover the broadcast sender used in this environment,
        // so it can be kissed before the actual test runs
        vm.startBroadcast();
        (, address broadcaster,) = vm.readCallers();
        vm.stopBroadcast();
        registry.kiss(broadcaster);
    }

    function _keys(uint256 n) internal pure returns (string[] memory keys) {
        keys = new string[](n);
        if (n > 0) keys[0] = "EXAMPLE_WAD";
        if (n > 1) keys[1] = "EXAMPLE_BPS";
        if (n > 2) revert("unsupported");
    }

    function testRun() public {
        string[] memory keys = _keys(2);
        int256[] memory vals = new int256[](2);
        vals[0] = 0.9e18;
        vals[1] = -50;

        script.run(registry, keys, vals);

        assertEq(registry.count(), 2, "testRun/count");

        assertEq(registry.getValue(bytes32(bytes(keys[0]))), vals[0], "testRun/first-value");
        assertEq(registry.getValue(bytes32(bytes(keys[1]))), vals[1], "testRun/second-value");
    }

    function testRevertRunNoItems() public {
        vm.expectRevert("SetValues/no-items");
        script.run(registry, new string[](0), new int256[](0));
    }

    function testRevertRunLengthMismatch() public {
        vm.expectRevert("SetValues/length-mismatch");
        script.run(registry, _keys(2), new int256[](1));
    }

    function testRevertRunEmptyKey() public {
        string[] memory keys = new string[](1);
        keys[0] = "";

        vm.expectRevert("SetValues/invalid-key");
        script.run(registry, keys, new int256[](1));
    }

    function testRevertRunKeyTooLong() public {
        string[] memory keys = new string[](1);
        keys[0] = "THIS_KEY_IS_LONGER_THAN_32_BYTES_STRING";

        vm.expectRevert("SetValues/invalid-key");
        script.run(registry, keys, new int256[](1));
    }
}
