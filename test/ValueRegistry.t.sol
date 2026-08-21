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

import {DssTest} from "dss-test/DssTest.sol";

import {ValueRegistry} from "../src/ValueRegistry.sol";

contract ValueRegistryTest is DssTest {
    ValueRegistry registry;

    address bud = address(0xb0d);
    address auth = address(0xa27);
    address unauth = address(0xdead);

    function setUp() public {
        registry = new ValueRegistry();
        registry.kiss(bud);
    }

    // --- Input helpers ---
    // Build the calldata arrays for the batch setters, so tests can be written without boilerplate.

    function _keyValues(bytes32 k1, int256 v1) internal pure returns (ValueRegistry.KeyValue[] memory items) {
        items = new ValueRegistry.KeyValue[](1);
        items[0] = ValueRegistry.KeyValue(k1, v1);
    }

    function _keyValues(bytes32 k1, int256 v1, bytes32 k2, int256 v2)
        internal
        pure
        returns (ValueRegistry.KeyValue[] memory items)
    {
        items = new ValueRegistry.KeyValue[](2);
        items[0] = ValueRegistry.KeyValue(k1, v1);
        items[1] = ValueRegistry.KeyValue(k2, v2);
    }

    function _keyValues(bytes32 k1, int256 v1, bytes32 k2, int256 v2, bytes32 k3, int256 v3)
        internal
        pure
        returns (ValueRegistry.KeyValue[] memory items)
    {
        items = new ValueRegistry.KeyValue[](3);
        items[0] = ValueRegistry.KeyValue(k1, v1);
        items[1] = ValueRegistry.KeyValue(k2, v2);
        items[2] = ValueRegistry.KeyValue(k3, v3);
    }

    function _keys(bytes32 k1) internal pure returns (bytes32[] memory ks) {
        ks = new bytes32[](1);
        ks[0] = k1;
    }

    function _keys(bytes32 k1, bytes32 k2) internal pure returns (bytes32[] memory ks) {
        ks = new bytes32[](2);
        ks[0] = k1;
        ks[1] = k2;
    }

    // --- State assertions ---

    /// @dev Asserts `key` holds `val` and sits at `index`, consistently across
    ///      every read path: getValue(), get(index) and list()
    function _assertEntryAt(uint256 index, bytes32 key, int256 val, string memory ctx) internal view {
        assertEq(registry.getValue(_keys(key)[0]), val, string.concat(ctx, "/getValue"));

        (bytes32 gotKey, int256 gotVal) = registry.get(index);
        assertEq(gotKey, key, string.concat(ctx, "/get-key"));
        assertEq(gotVal, val, string.concat(ctx, "/get-val"));

        assertEq(registry.list()[index], key, string.concat(ctx, "/list"));
    }

    /// @dev Asserts `key` is not registered: getValue() reverts
    function _assertAbsent(bytes32 key, string memory) internal {
        vm.expectRevert("ValueRegistry/invalid-key");
        registry.getValue(_keys(key)[0]);
    }

    /// @dev Asserts the registry holds exactly `n` keys, and that index `n` is
    ///      past the end
    function _assertCount(uint256 n, string memory ctx) internal {
        assertEq(registry.count(), n, string.concat(ctx, "/count"));
        assertEq(registry.list().length, n, string.concat(ctx, "/list-length"));

        vm.expectRevert("ValueRegistry/index-out-of-bounds");
        registry.get(n);
    }

    // --- Permissions ---

    function testConstructor() public {
        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Rely(address(this));
        ValueRegistry r = new ValueRegistry();

        assertEq(r.wards(address(this)), 1, "testConstructor/deployer-is-ward");
        assertEq(r.count(), 0, "testConstructor/starts-empty");
    }

    function testAuth() public {
        checkAuth(address(registry), "ValueRegistry");
    }

    function testAuthModifiersWards() public {
        bytes4[] memory authedMethods = new bytes4[](2);
        authedMethods[0] = ValueRegistry.kiss.selector;
        authedMethods[1] = ValueRegistry.diss.selector;

        vm.startPrank(unauth);
        checkModifier(address(registry), "ValueRegistry/not-authorized", authedMethods);
        vm.stopPrank();
    }

    function testAuthModifiersBuds() public {
        bytes4[] memory authedMethods = new bytes4[](2);
        authedMethods[0] = ValueRegistry.setValues.selector;
        authedMethods[1] = ValueRegistry.removeValues.selector;

        vm.startPrank(unauth);
        checkModifier(address(registry), "ValueRegistry/not-bud", authedMethods);
        vm.stopPrank();
    }

    function testKissDiss() public {
        assertEq(registry.buds(auth), 0, "testKissDiss/not-bud-by-default");

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Kiss(auth);
        registry.kiss(auth);
        assertEq(registry.buds(auth), 1, "testKissDiss/after-kiss");

        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.Diss(auth);
        registry.diss(auth);
        assertEq(registry.buds(auth), 0, "testKissDiss/after-diss");
    }

    function testTollMethods() public {
        vm.startPrank(unauth);
        vm.expectRevert("ValueRegistry/not-bud");
        registry.setValues(_keyValues("KEY", int256(1)));
        vm.expectRevert("ValueRegistry/not-bud");
        registry.removeValues(_keys("KEY"));
        vm.stopPrank();

        // wards are not buds by default
        vm.expectRevert("ValueRegistry/not-bud");
        registry.setValues(_keyValues("KEY", int256(1)));
        vm.expectRevert("ValueRegistry/not-bud");
        registry.removeValues(_keys("KEY"));
    }

    // --- setValues ---

    function testSetValue() public {
        // the registry starts empty
        _assertCount(0, "testSetValue/before-set");
        _assertAbsent("PARAM_WAD", "testSetValue/before-set");

        // add one value
        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.SetValue("PARAM_WAD", int256(0.9e18));
        vm.prank(bud);
        registry.setValues(_keyValues("PARAM_WAD", int256(0.9e18)));

        _assertCount(1, "testSetValue/after-set");
        _assertEntryAt(0, "PARAM_WAD", int256(0.9e18), "testSetValue/after-set");
    }

    function testSetValueOverwrite() public {
        vm.prank(bud);
        registry.setValues(_keyValues("PARAM_WAD", int256(0.9e18)));

        _assertCount(1, "testSetValueOverwrite/after-set");
        _assertEntryAt(0, "PARAM_WAD", int256(0.9e18), "testSetValueOverwrite/after-set");

        vm.prank(bud);

        // updating the value for an existing key
        registry.setValues(_keyValues("PARAM_WAD", int256(0.85e18)));

        _assertCount(1, "testSetValueOverwrite/overwrite-must-not-duplicate-key");
        _assertEntryAt(0, "PARAM_WAD", int256(0.85e18), "testSetValueOverwrite/after-overwrite");
    }

    function testSetValueZeroAndNegative() public {
        vm.prank(bud);
        registry.setValues(_keyValues("NEGATIVE_WAD", int256(-0.5e18), "ZERO_WAD", int256(0)));

        _assertCount(2, "testSetValueZeroAndNegative/after-set");
        _assertEntryAt(0, "NEGATIVE_WAD", int256(-0.5e18), "testSetValueZeroAndNegative/negative");
        // a key set to 0 is still present; 0 is a value, not an absence marker
        _assertEntryAt(1, "ZERO_WAD", int256(0), "testSetValueZeroAndNegative/zero");
    }

    function testUnsetKeyDoesNotAliasFirstSlot() public {
        // An unset key has `pos == 0`, which points at the first slot of the
        // keys array; presence must still be resolved via `keys[pos] == key`
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1)));

        _assertCount(1, "testUnsetKeyDoesNotAliasFirstSlot/after-set");
        _assertEntryAt(0, "A", int256(1), "testUnsetKeyDoesNotAliasFirstSlot/slot-0-untouched");

        _assertAbsent("UNSET", "testUnsetKeyDoesNotAliasFirstSlot/aliases-slot-0");

        vm.prank(bud);
        registry.setValues(_keyValues("UNSET", int256(2)));

        _assertCount(2, "testUnsetKeyDoesNotAliasFirstSlot/unset-key-must-be-appended-not-overwrite-slot-0");
        _assertEntryAt(1, "UNSET", int256(2), "testUnsetKeyDoesNotAliasFirstSlot/appended");
    }

    function testSetValueBatch() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1), "B", int256(2), "C", int256(3)));

        // every item lands, in the order it was given
        _assertCount(3, "testSetValueBatch/after-batch");
        _assertEntryAt(0, "A", int256(1), "testSetValueBatch/first");
        _assertEntryAt(1, "B", int256(2), "testSetValueBatch/second");
        _assertEntryAt(2, "C", int256(3), "testSetValueBatch/third");
    }

    function testSetValueBatchMixesInsertAndUpdate() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1)));

        _assertCount(1, "testSetValueBatchMixesInsertAndUpdate/after-set");
        _assertEntryAt(0, "A", int256(1), "testSetValueBatchMixesInsertAndUpdate/after-set");

        // "A" already exists (update), "B" does not (insert)
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(9), "B", int256(2)));

        _assertCount(2, "testSetValueBatchMixesInsertAndUpdate/update-must-not-duplicate-key");
        _assertEntryAt(0, "A", int256(9), "testSetValueBatchMixesInsertAndUpdate/updated-in-place");
        _assertEntryAt(1, "B", int256(2), "testSetValueBatchMixesInsertAndUpdate/inserted");
    }

    function testSetValueBatchDuplicateKeyLastWins() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1), "A", int256(7)));

        _assertCount(1, "testSetValueBatchDuplicateKeyLastWins/duplicate-in-batch-must-not-duplicate-key");
        _assertEntryAt(0, "A", int256(7), "testSetValueBatchDuplicateKeyLastWins/last-item-wins");
    }

    // --- removeValues ---

    function testRemoveValue() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1), "B", int256(2), "C", int256(3)));

        _assertCount(3, "testRemoveValue/after-set");
        _assertEntryAt(0, "A", int256(1), "testRemoveValue/after-set");
        _assertEntryAt(1, "B", int256(2), "testRemoveValue/after-set");
        _assertEntryAt(2, "C", int256(3), "testRemoveValue/after-set");

        // removing the middle key swaps the last key ("C") into its slot
        vm.expectEmit(true, false, false, true);
        emit ValueRegistry.RemoveValue("B");
        vm.prank(bud);
        registry.removeValues(_keys("B"));

        _assertCount(2, "testRemoveValue/after-remove");
        _assertAbsent("B", "testRemoveValue/after-remove");
        _assertEntryAt(0, "A", int256(1), "testRemoveValue/untouched-by-swap");
        _assertEntryAt(1, "C", int256(3), "testRemoveValue/last-key-moved-into-removed-slot");

        vm.prank(bud);
        registry.removeValues(_keys("C"));

        _assertCount(1, "testRemoveValue/moved-key-remains-removable");
        _assertAbsent("C", "testRemoveValue/after-second-remove");
        _assertEntryAt(0, "A", int256(1), "testRemoveValue/after-second-remove");

        // empties the registry
        vm.prank(bud);
        registry.removeValues(_keys("A"));

        _assertCount(0, "testRemoveValue/removing-last-key-empties-registry");
        _assertAbsent("A", "testRemoveValue/after-final-remove");
    }

    function testRemoveAndReAddValue() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1), "B", int256(2)));

        _assertCount(2, "testRemoveAndReAddValue/after-set");
        _assertEntryAt(0, "A", int256(1), "testRemoveAndReAddValue/after-set-A");
        _assertEntryAt(1, "B", int256(2), "testRemoveAndReAddValue/after-set-B");

        // removing "A" swaps "B" into slot 0
        vm.prank(bud);
        registry.removeValues(_keys("A"));

        _assertCount(1, "testRemoveAndReAddValue/after-remove");
        _assertEntryAt(0, "B", int256(2), "testRemoveAndReAddValue/last-key-moved-into-removed-slot");

        // re-adding "A" appends it at the end, with its new value
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(4)));

        _assertCount(2, "testRemoveAndReAddValue/after-re-add");
        _assertEntryAt(0, "B", int256(2), "testRemoveAndReAddValue/after-re-add-B");
        _assertEntryAt(1, "A", int256(4), "testRemoveAndReAddValue/after-re-add-A");
    }

    function testRemoveValueBatch() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1), "B", int256(2), "C", int256(3)));

        _assertCount(3, "testRemoveValueBatch/after-set");
        _assertEntryAt(0, "A", int256(1), "testRemoveValueBatch/after-set-A");
        _assertEntryAt(1, "B", int256(2), "testRemoveValueBatch/after-set-B");
        _assertEntryAt(2, "C", int256(3), "testRemoveValueBatch/after-set-C");

        // remove the first and last keys, leaving the middle one
        vm.prank(bud);
        registry.removeValues(_keys("A", "C"));

        _assertCount(1, "testRemoveValueBatch/after-batch-remove");
        _assertAbsent("A", "testRemoveValueBatch/after-batch-remove-A");
        _assertAbsent("C", "testRemoveValueBatch/after-batch-remove-C");
        _assertEntryAt(0, "B", int256(2), "testRemoveValueBatch/survivor-remains-readable");
    }

    function testRemoveValueBatchAllKeys() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1), "B", int256(2)));

        _assertCount(2, "testRemoveValueBatchAllKeys/after-set");
        _assertEntryAt(0, "A", int256(1), "testRemoveValueBatchAllKeys/after-set");
        _assertEntryAt(1, "B", int256(2), "testRemoveValueBatchAllKeys/after-set");

        vm.prank(bud);
        registry.removeValues(_keys("A", "B"));

        _assertCount(0, "testRemoveValueBatchAllKeys/after-removing-every-key");
        _assertAbsent("A", "testRemoveValueBatchAllKeys/after-removing-every-key");
        _assertAbsent("B", "testRemoveValueBatchAllKeys/after-removing-every-key");
    }

    function testEmptyBatchIsNoop() public {
        vm.prank(bud);
        registry.setValues(new ValueRegistry.KeyValue[](0));

        _assertCount(0, "testEmptyBatchIsNoop/after-empty-set");

        vm.prank(bud);
        registry.removeValues(new bytes32[](0));

        _assertCount(0, "testEmptyBatchIsNoop/after-empty-remove");
    }

    function testGetValue() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1), "B", int256(0), "C", int256(-3)));

        assertEq(registry.getValue("C"), int256(-3), "testGetValue/C/val");
        assertEq(registry.getValue("B"), int256(0), "testGetValue/B/first");
        assertEq(registry.getValue("A"), int256(1), "testGetValue/A/val");
    }

    // --- Reverts ---

    function testRevertGetValueUnsetKey() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1)));

        // unset key fails the call
        vm.expectRevert("ValueRegistry/invalid-key");
        registry.getValue("UNSET");
    }

    function testRevertRemoveValueBatchIsAtomic() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1)));

        _assertCount(1, "testRevertRemoveValueBatchIsAtomic/after-set");
        _assertEntryAt(0, "A", int256(1), "testRevertRemoveValueBatchIsAtomic/after-set");

        // "UNSET" reverts mid-batch, so the earlier removal of "A" must roll back
        vm.expectRevert("ValueRegistry/invalid-key");
        vm.prank(bud);
        registry.removeValues(_keys("A", "UNSET"));

        _assertEntryAt(0, "A", int256(1), "testRevertRemoveValueBatchIsAtomic/after-set");
    }

    function testRevertRemoveValueUnsetKey() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1)));

        _assertCount(1, "testRevertRemoveValueUnsetKey/after-set");
        _assertEntryAt(0, "A", int256(1), "testRevertRemoveValueUnsetKey/after-set");

        vm.expectRevert("ValueRegistry/invalid-key");
        vm.prank(bud);
        registry.removeValues(_keys("UNSET"));

        _assertCount(1, "testRevertRemoveValueUnsetKey/failed-remove-leaves-registry-intact");
        _assertEntryAt(0, "A", int256(1), "testRevertRemoveValueUnsetKey/after-failed-remove");
    }

    function testRevertRemoveValueEmptyRegistry() public {
        _assertCount(0, "testRevertRemoveValueEmptyRegistry/starts-empty");

        vm.expectRevert("ValueRegistry/invalid-key");
        vm.prank(bud);
        registry.removeValues(_keys("A"));

        _assertCount(0, "testRevertRemoveValueEmptyRegistry/still-empty");
    }

    function testRevertGetIndexOutOfBounds() public {
        vm.prank(bud);
        registry.setValues(_keyValues("A", int256(1)));

        _assertCount(1, "testRevertGetIndexOutOfBounds/after-set");

        (bytes32 key, int256 value) = registry.get(0);
        assertEq(key, bytes32("A"), "testRevertGetIndexOutOfBounds/after-set/key");
        assertEq(value, int256(1), "testRevertGetIndexOutOfBounds/after-set/value");

        vm.prank(bud);
        registry.removeValues(_keys("A"));

        _assertCount(0, "testRevertGetIndexOutOfBounds/after-remove");

        vm.expectRevert("ValueRegistry/index-out-of-bounds");
        registry.get(0);
    }
}
