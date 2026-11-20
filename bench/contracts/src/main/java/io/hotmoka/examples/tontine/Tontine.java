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

package io.hotmoka.examples.tontine;

import static io.takamaka.code.lang.Takamaka.event;
import static io.takamaka.code.lang.Takamaka.require;

import java.math.BigInteger;

import io.takamaka.code.lang.Contract;
import io.takamaka.code.lang.FromContract;
import io.takamaka.code.lang.Payable;
import io.takamaka.code.lang.PayableContract;
import io.takamaka.code.math.BigIntegerSupport;
import io.takamaka.code.util.StorageLinkedList;
import io.takamaka.code.util.StorageList;
import io.takamaka.code.util.StorageMap;
import io.takamaka.code.util.StorageTreeMap;

/**
 * A tontine (collective savings fund). The creator fixes the contribution; members join by
 * paying exactly that contribution. At each round, the creator calls distribuer: the next
 * member, in the order of the membership list (a circular queue), is credited with one
 * contribution and the round counter advances. A member can withdraw its balance; the creator
 * can refund every member in one call (linear loop over the members).
 */
public class Tontine extends Contract {
	private final PayableContract createur;
	private final BigInteger cotisation;
	private final StorageMap<PayableContract, BigInteger> soldes = new StorageTreeMap<>();
	private final StorageList<PayableContract> membres = new StorageLinkedList<>();
	private int tour;

	public @FromContract(PayableContract.class) Tontine(BigInteger cotisation) {
		this.createur = (PayableContract) caller();
		this.cotisation = cotisation;
	}

	public @Payable @FromContract(PayableContract.class) void rejoindre(BigInteger amount) {
		require(BigIntegerSupport.compareTo(amount, cotisation) == 0, "la cotisation doit etre exacte");
		PayableContract membre = (PayableContract) caller();
		require(!soldes.containsKey(membre), "deja membre");
		soldes.put(membre, BigInteger.ZERO);
		membres.add(membre);
		event(new Adhesion(membre));
	}

	public @FromContract void distribuer() {
		require(caller() == createur, "seul le createur distribue");
		PayableContract beneficiaire = membres.removeFirst();
		membres.add(beneficiaire);
		BigInteger solde = soldes.getOrDefault(beneficiaire, BigInteger.ZERO);
		soldes.put(beneficiaire, BigIntegerSupport.add(solde, cotisation));
		tour++;
		event(new Distribution(beneficiaire, tour));
	}

	public @FromContract(PayableContract.class) void retrait() {
		PayableContract membre = (PayableContract) caller();
		BigInteger solde = soldes.getOrDefault(membre, BigInteger.ZERO);
		require(BigIntegerSupport.compareTo(solde, BigInteger.ZERO) > 0, "rien a retirer");
		soldes.put(membre, BigInteger.ZERO);
		membre.receive(solde);
		event(new Retrait(membre, solde));
	}

	public @FromContract void rembourserTous() {
		require(caller() == createur, "seul le createur rembourse");
		membres.forEach(membre -> {
			BigInteger solde = soldes.getOrDefault(membre, BigInteger.ZERO);
			soldes.put(membre, BigInteger.ZERO);
			membre.receive(solde);
		});
		event(new Remboursement(tour));
	}
}
