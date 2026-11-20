/*
Copyright 2026 The hotmoka-gas-bounds authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package io.hotmoka.examples.micro;

import static io.takamaka.code.lang.Takamaka.event;

import java.math.BigInteger;

import io.takamaka.code.lang.Contract;
import io.takamaka.code.lang.Event;
import io.takamaka.code.lang.FromContract;
import io.takamaka.code.lang.Payable;
import io.takamaka.code.lang.PayableContract;
import io.takamaka.code.lang.Storage;
import io.takamaka.code.math.BigIntegerSupport;
import io.takamaka.code.util.StorageLinkedList;
import io.takamaka.code.util.StorageList;
import io.takamaka.code.util.StorageTreeArray;
import io.takamaka.code.util.StorageTreeMap;
import io.takamaka.code.util.StorageTreeSet;

/**
 * Microbenchmarks of the Hotmoka primitives of the cost model (hotmoka_gas.pl):
 * one method per primitive; the gas of a primitive is the gas of its method minus
 * the gas of noop().
 */
public class Micro extends Contract {
	private BigInteger x = BigInteger.ONE;
	private Item last;
	private final StorageTreeMap<Contract, BigInteger> map = new StorageTreeMap<>();
	private final StorageList<Item> items = new StorageLinkedList<>();
	private final StorageTreeArray<BigInteger> arr = new StorageTreeArray<>(9, BigInteger.ZERO);

	public static class Item extends Storage {
		private final BigInteger v;

		public Item(BigInteger v) {
			this.v = v;
		}

		public BigInteger v() {
			return v;
		}
	}

	public static class Ping extends Event {
		public @FromContract Ping() {}
	}

	/** Base cost of a transaction. */
	public void noop() {}

	/** balance / field read (C_FIELD). */
	public BigInteger readField() {
		return x;
	}

	/** State update of one field (assignment of a state variable). */
	public void writeField(BigInteger v) {
		x = v;
	}

	/** Coins received with the call (transfer(Caller, this, ...)). */
	public @Payable @FromContract void receiveCoins(BigInteger amount) {}

	/** Coins sent to another contract (transfer(this, To, ...)). */
	public void pay(PayableContract to, BigInteger amount) {
		to.receive(amount);
	}

	/** emit (C_EVENT). */
	public @FromContract void emit() {
		event(new Ping());
	}

	/** new_obj (C_NEW): a new storage object kept in a field. */
	public void newObj() {
		last = new Item(x);
	}

	/** list_add on a list of size n. */
	public void listAdd() {
		items.add(new Item(x));
	}

	/** Scan of the list of size n, reading one field of each element (load, C_LOAD). */
	public BigInteger scan() {
		BigInteger s = BigInteger.ZERO;
		for (Item it: items)
			s = BigIntegerSupport.add(s, it.v());
		return s;
	}

	/** map_put of a new key (the caller) in a tree map of size n. */
	public @FromContract void mapPut() {
		map.put(caller(), x);
	}

	/** map_put of an existing key in a tree map of size n. */
	public void mapUpdate(Contract k, BigInteger v) {
		map.put(k, v);
	}

	/** map_get in a tree map of size n. */
	public BigInteger mapGet(Contract k) {
		return map.getOrDefault(k, BigInteger.ZERO);
	}

	/** map_remove in a tree map of size n. */
	public void mapRemove(Contract k) {
		map.remove(k);
	}

	/** arr_get (C_ARR). */
	public BigInteger arrGet(int i) {
		return arr.get(i);
	}

	/** arr_set (C_ARR). */
	public void arrSet(int i, BigInteger v) {
		arr.set(i, v);
	}

	/** k contains + add in a temporary tree set (created in the transaction, never stored). */
	public BigInteger tmpSet(int k) {
		StorageTreeSet<BigInteger> seen = new StorageTreeSet<>();
		for (int i = 0; i < k; i++) {
			BigInteger b = BigInteger.valueOf(i * 7919L % 1000003L);
			if (!seen.contains(b))
				seen.add(b);
		}
		return x;
	}
}
