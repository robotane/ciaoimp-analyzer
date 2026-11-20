/*
Copyright 2021 Fausto Spoto

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

package io.hotmoka.examples.ponzi;

import static io.takamaka.code.lang.Takamaka.require;

import java.math.BigInteger;

import io.takamaka.code.lang.Contract;
import io.takamaka.code.lang.FromContract;
import io.takamaka.code.lang.Payable;
import io.takamaka.code.lang.PayableContract;
import io.takamaka.code.lang.StringSupport;
import io.takamaka.code.math.BigIntegerSupport;
import io.takamaka.code.util.StorageLinkedList;
import io.takamaka.code.util.StorageList;

/**
 * A contract for a pyramid investment scheme:
 * each new investment must be at least 10% greater than the previous one.
 * It is split equally among all previous investors, then the new
 * investor joins them.
 */
public class SimplePyramid extends Contract {
	private final BigInteger _10 = BigInteger.valueOf(10L);
	private final BigInteger _11 = BigInteger.valueOf(11L);
	private final StorageList<PayableContract> investors = new StorageLinkedList<>();
	private BigInteger previousInvestment = BigInteger.valueOf(1_000L);

	public @FromContract(PayableContract.class) SimplePyramid() {
		investors.add((PayableContract) caller());
	}

	public @Payable @FromContract(PayableContract.class) void invest(BigInteger amount) {
		// new investments must be at least 10% greater than the previous one
		BigInteger minimumInvestment = BigIntegerSupport.divide(BigIntegerSupport.multiply(previousInvestment, _11), _10);
		require(BigIntegerSupport.compareTo(amount, minimumInvestment) >= 0, () -> StringSupport.concat("you must invest at least ", minimumInvestment));

		BigInteger eachInvestorGets = BigIntegerSupport.divide(amount, BigInteger.valueOf(investors.size()));
		investors.forEach(investor -> investor.receive(eachInvestorGets));
		investors.addFirst((PayableContract) caller());
		previousInvestment = amount;
	}
}
