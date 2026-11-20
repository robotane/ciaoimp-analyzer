import java.io.*;
import java.math.BigInteger;
import java.security.MessageDigest;
import java.util.*;
import io.hotmoka.node.*;
import io.hotmoka.node.api.updates.Update;
import io.hotmoka.node.api.values.StorageReference;
import io.hotmoka.node.api.signatures.FieldSignature;
import io.hotmoka.node.api.types.*;
import io.hotmoka.node.api.transactions.TransactionReference;

/** Reads update specs (one transaction response per block, blocks separated by a line "END"),
 *  marshals the updates of each block, sorted as in a response (TreeSet), into one
 *  NodeMarshallingContext (the context used by Hotmoka responses), prints the byte count.
 *  obj := txname:progressive ; class/field type names are Java names.
 *  CT obj class jartx | ST obj defclass field ftype valueobj | IN obj defclass field int
 *  NU obj defclass field ftype | BO obj defclass field bool | BI obj defclass field bigint */
public class UpdSize {
  static Map<String, TransactionReference> txs = new HashMap<>();
  static TransactionReference tx(String n) throws Exception {
    var t = txs.get(n);
    if (t == null) { t = TransactionReferences.of(MessageDigest.getInstance("SHA-256").digest(n.getBytes())); txs.put(n, t); }
    return t;
  }
  static StorageReference ref(String s) throws Exception {
    var p = s.split(":"); return StorageValues.reference(tx(p[0]), new BigInteger(p[1]));
  }
  static StorageType type(String n) {
    switch (n) { case "int": return StorageTypes.INT; case "boolean": return StorageTypes.BOOLEAN; default: return StorageTypes.classNamed(n); }
  }
  static FieldSignature f(String c, String n, String t) { return FieldSignatures.of(StorageTypes.classNamed(c), n, type(t)); }
  public static void main(String[] a) throws Exception {
    var in = new BufferedReader(new InputStreamReader(System.in));
    SortedSet<Update> ups = new TreeSet<>();
    String line;
    while ((line = in.readLine()) != null) {
      line = line.trim(); if (line.isEmpty() || line.startsWith("#")) continue;
      var w = line.split("\\s+");
      switch (w[0]) {
        case "CT": ups.add(Updates.classTag(ref(w[1]), StorageTypes.classNamed(w[2]), tx(w[3]))); break;
        case "ST": ups.add(Updates.ofStorage(ref(w[1]), f(w[2], w[3], w[4]), ref(w[5]))); break;
        case "IN": ups.add(Updates.ofInt(ref(w[1]), f(w[2], w[3], "int"), Integer.parseInt(w[4]))); break;
        case "NU": ups.add(Updates.toNull(ref(w[1]), f(w[2], w[3], w[4]), false)); break;
        case "BO": ups.add(Updates.ofBoolean(ref(w[1]), f(w[2], w[3], "boolean"), Boolean.parseBoolean(w[4]))); break;
        case "BI": ups.add(Updates.ofBigInteger(ref(w[1]), f(w[2], w[3], "java.math.BigInteger"), new BigInteger(w[4]))); break;
        case "END": {
          var baos = new ByteArrayOutputStream();
          try (var ctx = NodeMarshallingContexts.of(baos)) { for (var u: ups) u.into(ctx); ctx.flush(); }
          System.out.println(baos.size() + " " + ups.size());
          ups = new TreeSet<>(); txs.clear(); break;
        }
      }
    }
  }
}
