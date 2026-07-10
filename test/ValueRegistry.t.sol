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

import "forge-std/Test.sol";

import { ValueRegistry } from "../src/ValueRegistry.sol";

contract ValueRegistryTest is Test {
    ValueRegistry registry;

    address bud = address(0xb0d);
    address auth = address(0xa27);
    address unauth = address(0xdead);

    function setUp() public {
        registry = new ValueRegistry();
        registry.kiss(bud);
    }

    function testConstructor() public {
        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Rely(address(this));
        ValueRegistry r = new ValueRegistry();

        assertEq(r.wards(address(this)), 1);
        assertEq(r.count(), 0);
    }

    function testAuth() public {
        assertEq(registry.wards(auth), 0);

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Rely(auth);
        registry.rely(auth);
        assertEq(registry.wards(auth), 1);

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Deny(auth);
        registry.deny(auth);
        assertEq(registry.wards(auth), 0);
    }

    function testAuthMethods() public {
        vm.startPrank(unauth);
        vm.expectRevert("ValueRegistry/not-authorized");
        registry.rely(auth);
        vm.expectRevert("ValueRegistry/not-authorized");
        registry.deny(auth);
        vm.expectRevert("ValueRegistry/not-authorized");
        registry.kiss(auth);
        vm.expectRevert("ValueRegistry/not-authorized");
        registry.diss(auth);
        vm.stopPrank();
    }

    function testTollMethods() public {
        vm.startPrank(unauth);
        vm.expectRevert("ValueRegistry/not-bud");
        registry.setValue("KEY", int256(1));
        vm.expectRevert("ValueRegistry/not-bud");
        registry.removeValue("KEY");
        vm.stopPrank();

        // wards are not buds by default
        vm.expectRevert("ValueRegistry/not-bud");
        registry.setValue("KEY", int256(1));
        vm.expectRevert("ValueRegistry/not-bud");
        registry.removeValue("KEY");
    }

    function testKissDiss() public {
        assertEq(registry.buds(auth), 0);

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Kiss(auth);
        registry.kiss(auth);
        assertEq(registry.buds(auth), 1);

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Diss(auth);
        registry.diss(auth);
        assertEq(registry.buds(auth), 0);
    }

    function testSetValue() public {
        assertEq(registry.count(), 0);
        assertEq(registry.has("OPT_UTIL_WAD"), false);

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.SetValue("OPT_UTIL_WAD", int256(0.9e18));
        vm.prank(bud);
        registry.setValue("OPT_UTIL_WAD", int256(0.9e18));

        assertEq(registry.count(), 1);
        assertTrue(registry.has("OPT_UTIL_WAD"));
        assertEq(registry.getValue("OPT_UTIL_WAD"), int256(0.9e18));

        (bytes32 key, int256 val) = registry.get(0);
        assertEq(key, "OPT_UTIL_WAD");
        assertEq(val, int256(0.9e18));

        bytes32[] memory listed = registry.list();
        assertEq(listed.length, 1);
        assertEq(listed[0], "OPT_UTIL_WAD");
    }

    function testSetValueOverwrite() public {
        vm.startPrank(bud);
        registry.setValue("OPT_UTIL_WAD", int256(0.9e18));
        registry.setValue("OPT_UTIL_WAD", int256(0.85e18));
        vm.stopPrank();

        assertEq(registry.count(), 1, "overwrite-must-not-duplicate-key");
        assertEq(registry.getValue("OPT_UTIL_WAD"), int256(0.85e18));
    }

    function testSetValueZeroAndNegative() public {
        vm.startPrank(bud);
        registry.setValue("NEGATIVE_WAD", int256(-0.5e18));
        registry.setValue("ZERO_WAD", int256(0));
        vm.stopPrank();

        assertEq(registry.getValue("NEGATIVE_WAD"), int256(-0.5e18));

        assertTrue(registry.has("ZERO_WAD"));
        assertEq(registry.getValue("ZERO_WAD"), int256(0));
    }

    function testRemoveValue() public {
        vm.startPrank(bud);
        registry.setValue("A", int256(1));
        registry.setValue("B", int256(2));
        registry.setValue("C", int256(3));

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.RemoveValue("B");
        registry.removeValue("B");
        vm.stopPrank();

        assertEq(registry.count(), 2);
        assertEq(registry.has("B"), false);
        vm.expectRevert("ValueRegistry/invalid-key");
        registry.getValue("B");

        (bytes32 key0, int256 val0) = registry.get(0);
        (bytes32 key1, int256 val1) = registry.get(1);
        assertEq(key0, "A");
        assertEq(val0, int256(1));
        assertEq(key1, "C", "last-key-moved-into-removed-slot");
        assertEq(val1, int256(3), "moved-key-keeps-value");

        assertEq(registry.getValue("C"), int256(3), "moved-key-remains-readable");
        vm.prank(bud);
        registry.removeValue("C");
        assertEq(registry.count(), 1, "moved-key-remains-removable");
        assertEq(registry.has("C"), false);
        assertEq(registry.getValue("A"), int256(1));

        vm.prank(bud);
        registry.removeValue("A");
        assertEq(registry.count(), 0, "removing-last-key-not-empties-registry");
        assertEq(registry.list().length, 0);
    }

    function testRemoveAndReAddValue() public {
        vm.startPrank(bud);
        registry.setValue("A", int256(1));
        registry.setValue("B", int256(2));
        registry.removeValue("A");
        registry.setValue("A", int256(4));
        vm.stopPrank();

        assertEq(registry.count(), 2);
        assertEq(registry.getValue("A"), int256(4));
        assertEq(registry.getValue("B"), int256(2));

        (bytes32 key1,) = registry.get(1);
        assertEq(key1, "A", "re-added-key-not-appended-at-end");
    }

    function testRevertRemoveValueUnsetKey() public {
        vm.expectRevert("ValueRegistry/invalid-key");
        vm.prank(bud);
        registry.removeValue("UNSET");
    }

    function testRevertGetValueUnsetKey() public {
        vm.expectRevert("ValueRegistry/invalid-key");
        registry.getValue("UNSET");
    }

    function testRevertGetIndexOutOfBounds() public {
        vm.expectRevert("ValueRegistry/index-out-of-bounds");
        registry.get(0);
    }
}
