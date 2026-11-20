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

package wtsc;

import java.io.PrintWriter;
import java.math.BigInteger;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;

import io.hotmoka.crypto.Base64;
import io.hotmoka.crypto.Entropies;
import io.hotmoka.crypto.SignatureAlgorithms;
import io.hotmoka.crypto.api.SignatureAlgorithm;
import io.hotmoka.crypto.api.Signer;
import io.hotmoka.node.ConstructorSignatures;
import io.hotmoka.node.MethodSignatures;
import io.hotmoka.node.StorageTypes;
import io.hotmoka.node.StorageValues;
import io.hotmoka.node.TransactionReferences;
import io.hotmoka.node.TransactionRequests;
import io.hotmoka.node.api.requests.SignedTransactionRequest;
import io.hotmoka.node.api.responses.NonInitialTransactionResponse;
import io.hotmoka.node.api.signatures.ConstructorSignature;
import io.hotmoka.node.api.signatures.MethodSignature;
import io.hotmoka.node.api.transactions.TransactionReference;
import io.hotmoka.node.api.types.ClassType;
import io.hotmoka.node.api.types.StorageType;
import io.hotmoka.node.api.values.StorageReference;
import io.hotmoka.node.api.values.StorageValue;
import io.hotmoka.node.remote.RemoteNodes;
import io.hotmoka.node.api.Node;

/**
 * Execution benchmark of the 16 WTSC contracts through a real Hotmoka node started by the moka CLI.
 * This is a client of the node (WebSocket local): same scenarios as the JUnit harness WtscBench / WtscBench2,
 * same CSV schema. Each account is created by its own transaction, through the faucet of the node,
 * exactly like "moka accounts create faucet".
 *
 * Options (name=value): uri, classpath (hash of the jar transaction), out, runs, n, warmup, gas,
 * contracts (comma separated list of contracts, default all), only=list|check.
 */
public class MokaBench {
	private static final BigInteger ONE = BigInteger.ONE;
	private static final ClassType PC = StorageTypes.PAYABLE_CONTRACT;
	private static final ClassType BI = StorageTypes.BIG_INTEGER;
	private static final ClassType CONTRACT = StorageTypes.CONTRACT;
	private static final ClassType UBI = StorageTypes.UNSIGNED_BIG_INTEGER;

	private final Map<String, String> opt = new HashMap<>();
	private Node node;
	private String chainId;
	private SignatureAlgorithm signature;
	private StorageReference gamete;
	private TransactionReference takamakaCode;
	private TransactionReference classpath;
	private BigInteger gas;
	private int runs, n, warmup;
	private Set<String> wanted;
	private PrintWriter out;
	private double emaMillis = 100.0;

	/** The accounts created for the current group of scenarios. */
	private final List<StorageReference> accounts = new ArrayList<>();
	private final List<PrivateKey> keys = new ArrayList<>();
	private final List<BigInteger> nonces = new ArrayList<>();

	private record M(BigInteger cpu, BigInteger ram, BigInteger storage, long micros) {
		BigInteger total() { return cpu.add(ram).add(storage); }
	}

	public static void main(String[] args) throws Exception {
		var b = new MokaBench();
		for (String a: args) {
			int i = a.indexOf('=');
			b.opt.put(a.substring(0, i), a.substring(i + 1));
		}
		b.run();
	}

	private String get(String k, String def) {
		return opt.getOrDefault(k, def);
	}

	private boolean want(String contract) {
		return wanted == null || wanted.contains(contract);
	}

	private boolean wantAny(String... contracts) {
		for (String c: contracts)
			if (want(c))
				return true;
		return false;
	}

	private void run() throws Exception {
		runs = Integer.parseInt(get("runs", "3"));
		n = Integer.parseInt(get("n", "100"));
		warmup = Integer.parseInt(get("warmup", "0"));
		gas = new BigInteger(get("gas", "10000000"));
		if (!get("contracts", "all").equals("all"))
			wanted = Set.of(get("contracts", "").split(","));
		node = RemoteNodes.of(new URI(get("uri", "ws://localhost:8001")), 120_000);
		try {
			chainId = node.getConfig().getChainId();
			signature = node.getConfig().getSignatureForRequests();
			takamakaCode = node.getTakamakaCode();
			var manifest = node.getManifest();
			gamete = node.runInstanceMethodCallTransaction(TransactionRequests.instanceViewMethodCall
					(manifest, BigInteger.valueOf(500_000), takamakaCode, MethodSignatures.GET_GAMETE, manifest))
					.get().asReturnedReference(MethodSignatures.GET_GAMETE, RuntimeException::new);
			classpath = TransactionReferences.of(get("classpath", ""));
			Path o = Paths.get(get("out", "build/moka/bench_moka.csv"));
			if (o.toAbsolutePath().getParent() != null)
				Files.createDirectories(o.toAbsolutePath().getParent());
			if (Files.exists(o) && !get("append", "no").equals("yes"))
				throw new IllegalStateException("refusing to overwrite " + o);
			out = new PrintWriter(Files.newBufferedWriter(o, java.nio.file.StandardOpenOption.CREATE, java.nio.file.StandardOpenOption.APPEND));
			if (Files.size(o) == 0)
				out.println("contract,operation,size_var,n,run,gas_cpu,gas_ram,gas_storage,gas_total,time_us");
			System.err.println("chainId='" + chainId + "' gamete=" + gamete + " classpath=" + classpath);

			if (get("only", "").equals("check")) {
				check();
				return;
			}
			if (wantAny("gradual_ponzi", "simple_pyramid", "simple_ponzi", "distributor")) ponziAndDistributor();
			if (wantAny("simple_auction", "blind_auction")) auctions();
			if (wantAny("crowdfunding", "ballot")) crowdfundingAndBallot();
			if (wantAny("example_coin", "crypto_buddy", "example_erc721", "crypto_shark")) tokens();
			if (wantAny("simple_shared_entity", "tictactoe")) sharedEntitiesAndTicTacToe();
			if (want("tontine")) tontine();
		}
		finally {
			if (out != null)
				out.close();
			node.close();
		}
	}

	// ------------------------------------------------------------ infrastructure

	private static ClassType cls(String name) {
		return StorageTypes.classNamed(name);
	}

	private M metrics(TransactionReference ref, long micros) throws Exception {
		var r = (NonInitialTransactionResponse) node.getResponse(ref);
		return new M(r.getGasConsumedForCPU(), r.getGasConsumedForRAM(), r.getGasConsumedForStorage(), micros);
	}

	/** Creates one account by its own transaction, through the unsigned faucet, like "moka accounts create faucet". */
	private M newAccount(BigInteger balance) throws Exception {
		var kp = signature.getKeyPair();
		String pub = Base64.toBase64String(signature.encodingOf(kp.getPublic()));
		var empty = SignatureAlgorithms.empty();
		var ek = empty.getKeyPair();
		Signer<SignedTransactionRequest<?>> signer = empty.getSigner(ek.getPrivate(), SignedTransactionRequest::toByteArrayWithoutSignature);
		var eoa = cls(StorageTypes.EOA + signature.getName().toUpperCase());
		var faucet = MethodSignatures.ofNonVoid(StorageTypes.GAMETE, "faucet" + signature.getName().toUpperCase(), eoa, BI, StorageTypes.STRING);
		var request = TransactionRequests.instanceMethodCall(signer, gamete, new BigInteger(64, new SecureRandom()), chainId,
				BigInteger.valueOf(1_000_000L), ONE, takamakaCode, faucet, gamete, StorageValues.bigIntegerOf(balance), StorageValues.stringOf(pub));
		long start = System.nanoTime();
		var future = node.postInstanceMethodCallTransaction(request);
		var ref = future.get().get().asReturnedReference(faucet, RuntimeException::new);
		long micros = (System.nanoTime() - start) / 1000;
		accounts.add(ref);
		keys.add(kp.getPrivate());
		nonces.add(BigInteger.ZERO);
		return metrics(future.getReferenceOfRequest(), micros);
	}

	/** Starts a group of scenarios with fresh accounts, each created by its own transaction. */
	private void setUp(int count) throws Exception {
		accounts.clear();
		keys.clear();
		nonces.clear();
		if (!get("accounts", "").isEmpty()) {
			loadAccounts(count);
			return;
		}
		for (int i = 0; i < count; i++)
			newAccount(BigInteger.TEN.pow(15));
		System.err.println("  " + count + " accounts created (one transaction each)");
	}

	/** Uses accounts created beforehand by "moka accounts create": option accounts=ref,ref,... and keys=directory of the .pem files. */
	private void loadAccounts(int count) throws Exception {
		var refs = get("accounts", "").split(",");
		if (refs.length < count)
			throw new IllegalStateException("need " + count + " accounts, only " + refs.length + " given");
		for (int i = 0; i < count; i++) {
			var ref = StorageValues.reference(refs[i]);
			var entropy = Entropies.load(Paths.get(get("keys", "."), refs[i] + ".pem"));
			accounts.add(ref);
			keys.add(entropy.keys("", signature).getPrivate());
			nonces.add(node.runInstanceMethodCallTransaction(TransactionRequests.instanceViewMethodCall
					(ref, BigInteger.valueOf(100_000), classpath, MethodSignatures.NONCE, ref)).get().asReturnedBigInteger(MethodSignatures.NONCE, RuntimeException::new));
		}
		System.err.println("  " + count + " accounts loaded from " + get("keys", "."));
	}

	private StorageReference account(int i) { return accounts.get(i); }

	private Signer<SignedTransactionRequest<?>> signer(int caller) throws Exception {
		return signature.getSigner(keys.get(caller), SignedTransactionRequest::toByteArrayWithoutSignature);
	}

	private BigInteger nextNonce(int caller) {
		var v = nonces.get(caller);
		nonces.set(caller, v.add(ONE));
		return v;
	}

	private M call(int caller, MethodSignature method, StorageReference receiver, StorageValue... actuals) throws Exception {
		var request = TransactionRequests.instanceMethodCall(signer(caller), account(caller), nextNonce(caller), chainId, gas, ONE, classpath, method, receiver, actuals);
		long start = System.nanoTime();
		var future = node.postInstanceMethodCallTransaction(request);
		future.get();
		long micros = (System.nanoTime() - start) / 1000;
		emaMillis = 0.9 * emaMillis + 0.1 * (micros / 1000.0);
		return metrics(future.getReferenceOfRequest(), micros);
	}

	private record Created(StorageReference ref, M m) {}

	private Created createM(int caller, ConstructorSignature constructor, StorageValue... actuals) throws Exception {
		var request = TransactionRequests.constructorCall(signer(caller), account(caller), nextNonce(caller), chainId, gas, ONE, classpath, constructor, actuals);
		long start = System.nanoTime();
		var future = node.postConstructorCallTransaction(request);
		var ref = future.get();
		long micros = (System.nanoTime() - start) / 1000;
		return new Created(ref, metrics(future.getReferenceOfRequest(), micros));
	}

	private StorageReference create(int caller, ConstructorSignature constructor, StorageValue... actuals) throws Exception {
		return createM(caller, constructor, actuals).ref();
	}

	private void record(String contract, String op, String var, int n, int run, M m) {
		int shown = run - warmup;
		if (shown >= 1) {
			out.printf("%s,%s,%s,%d,%d,%s,%s,%s,%s,%d%n", contract, op, var, n, shown, m.cpu, m.ram, m.storage, m.total(), m.micros);
			out.flush();
		}
	}

	private static StorageValue big(long v) { return StorageValues.bigIntegerOf(v); }

	private int window(int transactions) { return (int) (4000 + 3 * emaMillis * transactions); }

	private static void waitUntil(long epochMillis) throws InterruptedException {
		long d = epochMillis - System.currentTimeMillis();
		if (d > 0)
			Thread.sleep(d);
	}

	private StorageReference bytes32(int caller, byte[] b) throws Exception {
		var args = new StorageValue[32];
		var types = new StorageType[32];
		for (int i = 0; i < 32; i++) {
			args[i] = StorageValues.byteOf(b[i]);
			types[i] = StorageTypes.BYTE;
		}
		return create(caller, ConstructorSignatures.of(StorageTypes.BYTES32_SNAPSHOT, types), args);
	}

	private void log(String s) { System.err.println(s); }

	/** Runs numbered 1..runs are recorded; with warmup > 0 the first runs are executed but not recorded. */
	private int total() { return runs + warmup; }

	// ------------------------------------------------------------ sanity check

	/** A short sequence whose gas can be compared with the same sequence sent through the moka CLI. */
	private void check() throws Exception {
		if (!get("accounts", "").isEmpty()) {
			accounts.clear();
			keys.clear();
			nonces.clear();
			loadAccounts(4);
		}
		else {
			accounts.clear();
			keys.clear();
			nonces.clear();
			for (int i = 0; i < 4; i++)
				show("account_create" + i, newAccount(BigInteger.TEN.pow(15)));
		}
		var sp = cls("io.hotmoka.examples.ponzi.SimplePonzi");
		var invest = MethodSignatures.ofVoid(sp, "invest", BI);
		var created = createM(0, ConstructorSignatures.of(sp));
		show("ponzi_create", created.m());
		int[] who = {1, 2, 3};
		long[] amt = {1000, 2000, 3000};
		for (int i = 0; i < 3; i++)
			show("ponzi_invest" + (i + 1), call(who[i], invest, created.ref(), big(amt[i])));

		var ec = cls("io.hotmoka.examples.tokens.ExampleCoin");
		var transfer = MethodSignatures.ofNonVoid(ec, "transfer", StorageTypes.BOOLEAN, CONTRACT, UBI);
		var uc = ConstructorSignatures.of(UBI, StorageTypes.LONG);
		var coin = createM(0, ConstructorSignatures.of(ec));
		show("coin_create", coin.m());
		var u1000 = createM(0, uc, StorageValues.longOf(1000));
		show("ubi1000_create", u1000.m());
		show("coin_transfer1", call(0, transfer, coin.ref(), account(1), u1000.ref()));
		show("coin_transfer2", call(0, transfer, coin.ref(), account(2), u1000.ref()));
	}

	private void show(String label, M m) {
		System.out.printf("CHECK %s cpu=%s ram=%s storage=%s%n", label, m.cpu, m.ram, m.storage);
	}

	// ------------------------------------------------------------ scenarios (same as WtscBench / WtscBench2)

	private void ponziAndDistributor() throws Exception {
		log("group ponzi/distributor");
		setUp(n + 2);
		var bi = StorageTypes.BIG_INTEGER;
		for (int run = 1; run <= total(); run++) {
			log("  run " + run);
			if (want("gradual_ponzi")) {
				var gp = cls("io.hotmoka.examples.ponzi.GradualPonzi");
				var gpRef = create(0, ConstructorSignatures.of(gp));
				var gpInvest = MethodSignatures.ofVoid(gp, "invest", bi);
				for (int i = 1; i <= n; i++)
					record("gradual_ponzi", "invest", "I", i, run, call(i, gpInvest, gpRef, StorageValues.bigIntegerOf(1_000L)));
			}
			if (want("simple_pyramid")) {
				var sp = cls("io.hotmoka.examples.ponzi.SimplePyramid");
				var spRef = create(0, ConstructorSignatures.of(sp));
				var spInvest = MethodSignatures.ofVoid(sp, "invest", bi);
				BigInteger amount = BigInteger.valueOf(1_100L);
				for (int i = 1; i <= n; i++) {
					record("simple_pyramid", "invest", "I", i, run, call(i, spInvest, spRef, StorageValues.bigIntegerOf(amount)));
					amount = amount.multiply(BigInteger.valueOf(11)).divide(BigInteger.TEN).add(ONE);
				}
			}
			if (want("simple_ponzi")) {
				var po = cls("io.hotmoka.examples.ponzi.SimplePonzi");
				var poRef = create(0, ConstructorSignatures.of(po));
				var poInvest = MethodSignatures.ofVoid(po, "invest", bi);
				BigInteger amount = BigInteger.valueOf(1_000L);
				for (int i = 1; i <= n; i++) {
					record("simple_ponzi", "invest", "n", i - 1, run, call(i, poInvest, poRef, StorageValues.bigIntegerOf(amount)));
					amount = amount.multiply(BigInteger.valueOf(11)).divide(BigInteger.TEN).add(ONE);
				}
			}
			if (want("distributor")) {
				var di = cls("io.hotmoka.examples.distributor.Distributor");
				var diRef = create(0, ConstructorSignatures.of(di));
				var add = MethodSignatures.ofVoid(di, "addAsPayee");
				var distribute = MethodSignatures.ofVoid(di, "distribute", bi);
				for (int i = 1; i <= n; i++) {
					record("distributor", "add_as_payee", "P", i - 1, run, call(i, add, diRef));
					record("distributor", "distribute", "P", i, run, call(n + 1, distribute, diRef, StorageValues.bigIntegerOf(1_000_000L)));
				}
			}
		}
	}

	/** Like call, but fails if the transaction failed (the gas of a failed transaction would not be the gas of the operation). */
	private M callChecked(int caller, MethodSignature method, StorageReference receiver, StorageValue... actuals) throws Exception {
		var request = TransactionRequests.instanceMethodCall(signer(caller), account(caller), nextNonce(caller), chainId, gas, ONE, classpath, method, receiver, actuals);
		long start = System.nanoTime();
		var future = node.postInstanceMethodCallTransaction(request);
		future.get();
		long micros = (System.nanoTime() - start) / 1000;
		var response = node.getResponse(future.getReferenceOfRequest());
		if (response.getClass().getSimpleName().contains("Failed"))
			throw new IllegalStateException("transaction failed: " + method + " " + response);
		return metrics(future.getReferenceOfRequest(), micros);
	}

	/**
	 * Tontine (witness contract, not in the 16 WTSC contracts). Account 0 is the creator, accounts 1..N the members.
	 * rejoindre is measured at every size 0..N-1; at the sizes 4, 6, 8, ..., N (and, on fresh contracts, 1, 2, 3)
	 * distribuer, retrait and rembourserTous are measured with n members.
	 */
	private void tontine() throws Exception {
		log("group tontine");
		int nn = Math.min(n, 50);
		setUp(nn + 1);
		var t = cls("io.hotmoka.examples.tontine.Tontine");
		var cons = ConstructorSignatures.of(t, BI);
		var rejoindre = MethodSignatures.ofVoid(t, "rejoindre", BI);
		var distribuer = MethodSignatures.ofVoid(t, "distribuer");
		var retrait = MethodSignatures.ofVoid(t, "retrait");
		var rembourser = MethodSignatures.ofVoid(t, "rembourserTous");
		var cot = StorageValues.bigIntegerOf(1_000L);
		for (int run = 1; run <= total(); run++) {
			log("  run " + run);
			// small sizes, on fresh contracts: 1 credit to pay back (distribuer, rembourserTous) or to withdraw (distribuer, retrait)
			for (int s = 1; s <= 3 && s <= nn; s++) {
				var a = create(0, cons, cot);
				for (int i = 1; i <= s; i++)
					callChecked(i, rejoindre, a, cot);
				record("tontine", "distribuer", "n", s, run, callChecked(0, distribuer, a));
				record("tontine", "rembourser_tous", "n", s, run, callChecked(0, rembourser, a));
				var b = create(0, cons, cot);
				for (int i = 1; i <= s; i++)
					callChecked(i, rejoindre, b, cot);
				callChecked(0, distribuer, b);
				record("tontine", "retrait", "n", s, run, callChecked(1, retrait, b));
			}
			var c = create(0, cons, cot);
			var queue = new java.util.ArrayDeque<Integer>();
			for (int i = 1; i <= nn; i++) {
				record("tontine", "rejoindre", "n", i - 1, run, callChecked(i, rejoindre, c, cot));
				queue.addLast(i);
				if (i >= 4 && i % 2 == 0) {
					// credit the next member, who withdraws; credit the following one, whom the creator refunds
					record("tontine", "distribuer", "n", i, run, callChecked(0, distribuer, c));
					int first = queue.removeFirst();
					queue.addLast(first);
					record("tontine", "retrait", "n", i, run, callChecked(first, retrait, c));
					callChecked(0, distribuer, c);
					queue.addLast(queue.removeFirst());
					record("tontine", "rembourser_tous", "n", i, run, callChecked(0, rembourser, c));
				}
			}
		}
	}

	private void auctions() throws Exception {
		log("group auctions");
		setUp(n + 3);
		var sa = cls("io.hotmoka.examples.auction.SimpleAuction");
		var saCons = ConstructorSignatures.of(sa, StorageTypes.INT, PC);
		var saBid = MethodSignatures.ofVoid(sa, "bid", BI);
		var saEnd = MethodSignatures.ofNonVoid(sa, "auctionEnd", PC);

		var ba = cls("io.hotmoka.examples.auction.BlindAuction");
		var revealedType = cls("io.hotmoka.examples.auction.BlindAuction$RevealedBid");
		var baCons = ConstructorSignatures.of(ba, StorageTypes.INT, StorageTypes.INT);
		var baBid = MethodSignatures.ofVoid(ba, "bid", BI, StorageTypes.BYTES32_SNAPSHOT);
		var baReveal = MethodSignatures.ofVoid(ba, "reveal", revealedType);
		var baEnd = MethodSignatures.ofNonVoid(ba, "auctionEnd", PC);
		var revealedCons = ConstructorSignatures.of(revealedType, BI, StorageTypes.BOOLEAN, StorageTypes.BYTES32_SNAPSHOT);
		var digest = MessageDigest.getInstance("SHA-256");
		var random = new Random(42);

		for (int run = 1; run <= total(); run++) {
			log("  run " + run);
			if (want("simple_auction")) {
				int smallTime = 4000;
				var small = create(0, saCons, StorageValues.intOf(smallTime), account(0));
				long smallEnd = System.currentTimeMillis() + smallTime + 2000;
				call(1, saBid, small, big(10));

				int time = window(n);
				var auction = create(0, saCons, StorageValues.intOf(time), account(0));
				long end = System.currentTimeMillis() + time + 2000;
				for (int i = 1; i <= n; i++)
					record("simple_auction", "bid", "b", i - 1, run, call(i, saBid, auction, big(10L * i)));

				waitUntil(smallEnd);
				record("simple_auction", "auction_end", "b", 1, run, call(0, saEnd, small));
				waitUntil(end);
				record("simple_auction", "auction_end", "b", n, run, call(0, saEnd, auction));
			}

			if (want("blind_auction")) {
				int total = 2 * n;
				var value = new BigInteger[total];
				var deposit = new BigInteger[total];
				var hashRef = new StorageReference[total];
				var revealRef = new StorageReference[total];
				for (int j = 0; j < total; j++) {
					value[j] = BigInteger.valueOf(j < n ? 10L * (j + 1) : 1L);
					deposit[j] = value[j].add(BigInteger.valueOf(5));
					var salt = new byte[32];
					random.nextBytes(salt);
					digest.reset();
					digest.update(value[j].toByteArray());
					digest.update((byte) 1);
					digest.update(salt);
					hashRef[j] = bytes32(0, digest.digest());
					var saltRef = bytes32(0, salt);
					revealRef[j] = create(0, revealedCons, StorageValues.bigIntegerOf(value[j]), StorageValues.booleanOf(false), saltRef);
				}

				int biddingTime = window(total), revealTime = window(total);
				var blind = create(0, baCons, StorageValues.intOf(biddingTime), StorageValues.intOf(revealTime));
				long created = System.currentTimeMillis();
				for (int j = 0; j < total; j++) {
					int caller = j < n ? j + 1 : n + 1;
					M m = call(caller, baBid, blind, StorageValues.bigIntegerOf(deposit[j]), hashRef[j]);
					if (j < n)
						record("blind_auction", "bid", "b", j, run, m);
					else
						record("blind_auction", "bid", "k", j - n, run, m);
				}

				waitUntil(created + biddingTime + 2000);
				for (int j = 0; j < total; j++) {
					int caller = j < n ? j + 1 : n + 1;
					M m = call(caller, baReveal, blind, revealRef[j]);
					if (j < n)
						record("blind_auction", "reveal", "b", j, run, m);
					else
						record("blind_auction", "reveal", "k", n - (j - n), run, m);
				}

				waitUntil(created + biddingTime + revealTime + 2000);
				record("blind_auction", "auction_end", "b", n, run, call(0, baEnd, blind));
			}
		}
	}

	private void crowdfundingAndBallot() throws Exception {
		log("group crowdfunding/ballot");
		setUp(2 * n + 3);
		var cf = cls("io.hotmoka.examples.crowdfunding.CrowdFunding");
		var newCampaign = MethodSignatures.ofNonVoid(cf, "newCampaign", StorageTypes.INT, PC, BI);
		var contribute = MethodSignatures.ofVoid(cf, "contribute", BI, StorageTypes.INT);
		var check = MethodSignatures.ofNonVoid(cf, "checkGoalReached", StorageTypes.BOOLEAN, StorageTypes.INT);

		var ballot = cls("io.hotmoka.examples.voting.Ballot");
		var ballotCons = ConstructorSignatures.of(ballot, StorageTypes.INT);
		var give = MethodSignatures.ofVoid(ballot, "giveRightToVote", CONTRACT);
		var vote = MethodSignatures.ofVoid(ballot, "voteFor", StorageTypes.INT);
		var delegate = MethodSignatures.ofVoid(ballot, "delegate", CONTRACT);
		var winner = MethodSignatures.ofNonVoid(ballot, "winnerName", StorageTypes.STRING);

		for (int run = 1; run <= total(); run++) {
			log("  run " + run);
			if (want("crowdfunding")) {
				var cfRef = create(0, ConstructorSignatures.of(cf));
				for (int i = 1; i <= n; i++) {
					record("crowdfunding", "new_campaign", "C", i - 1, run, call(0, newCampaign, cfRef, account(0), StorageValues.bigIntegerOf(BigInteger.TEN.pow(12))));
					record("crowdfunding", "contribute", "C", i, run, call(1, contribute, cfRef, big(100), StorageValues.intOf(i - 1)));
					record("crowdfunding", "check_goal_reached", "C", i, run, call(0, check, cfRef, StorageValues.intOf(i - 1)));
				}
			}
			if (want("ballot")) {
				var b1 = create(0, ballotCons, StorageValues.intOf(3));
				for (int i = 1; i <= n; i++) {
					record("ballot", "give_right", "V", i - 1, run, call(0, give, b1, account(i)));
					record("ballot", "vote", "V", i, run, call(i, vote, b1, StorageValues.intOf(0)));
				}

				var b2 = create(0, ballotCons, StorageValues.intOf(3));
				for (int i = 1; i <= 2 * n + 1; i++)
					call(0, give, b2, account(i));
				for (int l = 1; l <= n; l++) {
					call(l, delegate, b2, account(l + 1));
					record("ballot", "delegate", "L", l, run, call(n + 1 + l, delegate, b2, account(1)));
				}

				for (int p = 1; p <= n; p++) {
					var b3 = create(0, ballotCons, StorageValues.intOf(p));
					record("ballot", "winner", "P", p, run, call(0, winner, b3));
				}
			}
		}
	}

	private StorageReference ubi(long v) throws Exception {
		return create(0, ConstructorSignatures.of(UBI, StorageTypes.LONG), StorageValues.longOf(v));
	}

	private void tokens() throws Exception {
		log("group tokens");
		setUp(n + 4);
		int sink = n + 1, operator = n + 2;

		for (int run = 1; run <= total(); run++) {
			log("  run " + run);
			var u1000 = ubi(1000);
			var u1 = ubi(1);
			var u500 = ubi(500);

			if (want("example_coin")) {
				var ec = cls("io.hotmoka.examples.tokens.ExampleCoin");
				var ecTransfer = MethodSignatures.ofNonVoid(ec, "transfer", StorageTypes.BOOLEAN, CONTRACT, UBI);
				var ecMint = MethodSignatures.ofVoid(ec, "mint", CONTRACT, UBI);
				var ecBurn = MethodSignatures.ofVoid(ec, "burn", CONTRACT, UBI);
				var coinA = create(0, ConstructorSignatures.of(ec));
				for (int i = 1; i <= n; i++)
					record("example_coin", "token_transfer", "T", i - 1, run, call(0, ecTransfer, coinA, account(i), u1000));
				var coinB = create(0, ConstructorSignatures.of(ec));
				for (int i = 1; i <= n; i++) {
					record("example_coin", "mint", "T", i - 1, run, call(0, ecMint, coinB, account(i), u1000));
					record("example_coin", "burn", "T", i, run, call(0, ecBurn, coinB, account(i), u1));
				}
			}

			if (want("crypto_buddy")) {
				var cb = cls("io.hotmoka.tutorial.examples.erc20.CryptoBuddy");
				var cbTransfer = MethodSignatures.ofNonVoid(cb, "transfer", StorageTypes.BOOLEAN, CONTRACT, UBI);
				var cbApprove = MethodSignatures.ofNonVoid(cb, "approve", StorageTypes.BOOLEAN, CONTRACT, UBI);
				var cbTransferFrom = MethodSignatures.ofNonVoid(cb, "transferFrom", StorageTypes.BOOLEAN, CONTRACT, CONTRACT, UBI);
				var buddy = create(0, ConstructorSignatures.of(cb));
				for (int i = 1; i <= n; i++) {
					record("crypto_buddy", "token_transfer", "T", i - 1, run, call(0, cbTransfer, buddy, account(i), u1000));
					record("crypto_buddy", "approve", "T", i - 1, run, call(0, cbApprove, buddy, account(i), u500));
					record("crypto_buddy", "transferFrom", "T", i, run, call(i, cbTransferFrom, buddy, account(0), account(i), u1));
				}
			}

			if (want("example_erc721")) {
				var e7 = cls("io.hotmoka.examples.tokens.ExampleERC721Coin");
				var e7Mint = MethodSignatures.ofVoid(e7, "mint", CONTRACT, BI);
				var e7TransferFrom = MethodSignatures.ofVoid(e7, "transferFrom", CONTRACT, CONTRACT, BI);
				var erc = create(0, ConstructorSignatures.of(e7));
				for (int i = 1; i <= n; i++) {
					record("example_erc721", "mint", "O", i - 1, run, call(0, e7Mint, erc, account(i), big(i)));
					record("example_erc721", "transferFrom", "O", i, run, call(i, e7TransferFrom, erc, account(i), account(sink), big(i)));
				}
			}

			if (want("crypto_shark")) {
				var cs = cls("io.hotmoka.tutorial.examples.erc721.CryptoShark");
				var csMint = MethodSignatures.ofVoid(cs, "mint", CONTRACT, BI);
				var csApprove = MethodSignatures.ofVoid(cs, "approve", CONTRACT, BI);
				var csSetAll = MethodSignatures.ofVoid(cs, "setApprovalForAll", CONTRACT, StorageTypes.BOOLEAN);
				var csTransferFrom = MethodSignatures.ofVoid(cs, "transferFrom", CONTRACT, CONTRACT, BI);
				var shark = create(0, ConstructorSignatures.of(cs));
				for (int i = 1; i <= n; i++) {
					record("crypto_shark", "mint", "O", i - 1, run, call(0, csMint, shark, account(i), big(i)));
					record("crypto_shark", "approve", "O", i, run, call(i, csApprove, shark, account(sink), big(i)));
					record("crypto_shark", "setApprovalForAll", "O", i, run, call(i, csSetAll, shark, account(operator), StorageValues.booleanOf(true)));
					record("crypto_shark", "transferFrom", "O", i, run, call(sink, csTransferFrom, shark, account(i), account(sink), big(i)));
				}
			}
		}
	}

	private void sharedEntitiesAndTicTacToe() throws Exception {
		log("group shared entity / tictactoe");
		setUp(n + 3);
		var se = cls("io.hotmoka.examples.sharedentities.SimpleSharedEntity1");
		var offerType = cls("io.hotmoka.examples.sharedentities.SharedEntity1$Offer");
		var seCons = ConstructorSignatures.of(se, PC, BI);
		var offerCons = ConstructorSignatures.of(offerType, BI, BI, StorageTypes.LONG);
		var place = MethodSignatures.ofVoid(se, "place", BI, offerType);
		var accept = MethodSignatures.ofVoid(se, "accept", BI, offerType);

		var ttt = cls("io.hotmoka.examples.tictactoe.TicTacToe");
		var play = MethodSignatures.ofVoid(ttt, "play", StorageTypes.LONG, StorageTypes.INT, StorageTypes.INT);
		int[][] moves = { {1, 1}, {2, 1}, {1, 2}, {2, 2}, {3, 1}, {3, 2}, {2, 3}, {1, 3}, {3, 3} };
		final int GAMES = 5;

		for (int run = 1; run <= total(); run++) {
			log("  run " + run);
			if (want("simple_shared_entity")) {
				var ent = create(0, seCons, account(0), big(n + 10));
				for (int i = 1; i <= n; i++) {
					var offer = create(0, offerCons, big(1), big(1), StorageValues.longOf(3_600_000L));
					record("simple_shared_entity", "place_offer", "S", i, run, call(0, place, ent, big(0), offer));
					record("simple_shared_entity", "accept", "S", i, run, call(i, accept, ent, big(1), offer));
				}

				var ent2 = create(0, seCons, account(0), big(n + 10));
				var offers = new StorageReference[n];
				for (int j = 0; j < n; j++) {
					offers[j] = create(0, offerCons, big(1), big(1), StorageValues.longOf(3_600_000L));
					record("simple_shared_entity", "place_offer", "F", j, run, call(0, place, ent2, big(0), offers[j]));
				}
				for (int j = 0; j < n; j++)
					record("simple_shared_entity", "accept", "F", n - j, run, call(1, accept, ent2, big(1), offers[j]));
			}

			if (want("tictactoe")) {
				for (int g = 0; g < GAMES; g++) {
					var game = create(0, ConstructorSignatures.of(ttt));
					for (int k = 0; k < moves.length; k++) {
						int player = k % 2 == 0 ? 1 : 2;
						long amount = k < 2 ? 100 : 0;
						record("tictactoe", "play", "moves", k, run, call(player, play, game, StorageValues.longOf(amount), StorageValues.intOf(moves[k][0]), StorageValues.intOf(moves[k][1])));
					}
				}
			}
		}
	}
}
