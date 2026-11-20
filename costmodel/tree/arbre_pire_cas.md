# Coût de gaz pire cas des arbres Takamaka (StorageTreeMap & co.)

Objectif : remplacer les constantes d'arbre ajustées sur mesures (`C_TREEW1 = 11603`, ajustée sur
un seul lancement du nœud, et les intercepts/pentes des microbenchmarks) par des valeurs **sûres**,
dérivées du code, valables **quel que soit l'ordre des clés** (adresses aléatoires d'un nœud à
l'autre). Résultat : `data/constants_moka_sur.json`, produit par `costmodel/tree/derive_arbre.py`.

Sources lues (lecture seule) :
- Takamaka : `io-takamaka-code-1.8.1-sources.jar` (Maven Central ; le jar binaire est identique,
  sha1 `6ed51ed3…`, à celui du nœud `io-hotmoka-docker/modules/explicit_or_automatic/`).
  Classes : `io/takamaka/code/util/{SnapshottableStorageTreeMap,StorageTreeMap,StorageTreeSet,SnapshottableStorageTreeSet}.java`,
  `io/takamaka/code/lang/StorageSupport.java`, `io/takamaka/code/math/BigIntegerSupport.java`.
- Hotmoka 1.12.3 (sources publiques, version 1.12.3) : modèle de gaz, instrumentation, extraction des
  mises à jour, sérialisation (références ci-dessous).

## 1. D'où vient le gaz

`gaz = CPU + RAM + stockage`.

- **CPU et RAM** : ajoutés par l'instrumentation du jar à l'installation
  (`io-hotmoka-instrumentation/.../instrumentationsOfMethod/AddGasUpdates.java`) : au début de
  chaque bloc de base, `Runtime.chargeN()` avec N = somme des coûts des instructions du bloc
  (`cpuCostOf`, l. 333 : 1 par instruction, 2 arithmétique/tableau/champ/select, 8 invoke,
  16 allocation — `StandardGasCostModel.java` l. 85…) ; avant chaque `invoke` et `new`,
  `Runtime.chargeForRAM(…)` (`addRamGasUpdate`, l. 119 : 32 + 8 par argument et receveur ;
  8 + 4 par champ). Les accesseurs de champs ajoutés (`§get_…`, chargement paresseux) et les
  méthodes de `Runtime` ne sont pas facturés.
- **Stockage** : 80 gaz par octet (`StandardGasCostModel.storageCostOfByte`, l. 121) de la réponse
  sérialisée (`NonInitialResponseBuilderImpl.chargeGasForStorageOf`, l. 506). La réponse contient
  les mises à jour extraites par `UpdatesExtractor` (`io-hotmoka-node-local/.../builders/UpdatesExtractor.java`) :
  objet neuf atteignable → `ClassTag` + **tous** ses champs (l. 176), objet ancien → un update par
  champ **modifié** (l. 302). Les objets neufs devenus inatteignables (temporaires) ne coûtent rien
  en stockage, seulement en CPU/RAM.
- **Sérialisation** (`io-hotmoka-node/.../marshalling/*Marshaller.java`) : une référence de
  stockage, une référence de transaction et une signature de champ sont partagées dans la réponse :
  1re occurrence complète (référence = 1 + hash de transaction 32 octets (partagé lui aussi) +
  progressif compact), occurrences suivantes 1 octet. Le nom de classe
  `SNAPSHOTTABLE_STORAGE_TREE_MAP_NODE_NAME` de `io-takamaka-code-constants` vaut
  `…SnapshottableStorageMap$Node` (sans `Tree`) : les sélecteurs compacts prévus pour les nœuds
  des arbres persistants ne s'appliquent donc jamais, leurs champs sont écrits avec leur signature
  (partagée après la 1re fois).
- **Comparaison de clés** (`StorageSupport.compare`, l. 41) : clés objets de stockage (comptes,
  contrats) → `compareByStorageReference` → `Runtime.compareStorageReferencesOf` (l. 215), non
  facturé : **coût constant, indépendant des octets de l'adresse**. Clés `BigInteger` →
  `BigIntegerSupport.compareTo` (l. 100) facture `bitLength` des deux clés.

Les octets ne sont pas comptés à la main : `costmodel/tree/UpdSize.java` construit les mises à jour avec
les classes de Hotmoka (`Updates.*`, `NodeMarshallingContexts`) et mesure leur taille.

## 2. L'arbre

`StorageTreeMap` (mutable) et `SnapshottableStorageTreeMap` (persistant, utilisé par ERC20,
ERC721, SimpleSharedEntity) sont des **arbres rouge-noir penchés à gauche** (LLRB de Sedgewick) :
`put` récursif + `rotateLeft`/`rotateRight`/`flipColors` à la remontée
(`SnapshottableStorageTreeMap.java` l. 431, `StorageTreeMap.java` l. 344), `remove` descendant
avec `moveRedLeft`/`moveRedRight` puis `balance` (l. 510, l. 170, l. 183). La version
persistante ne modifie jamais un nœud : chaque `setLeft`, rotation, `flipColors`, `fixSize` crée
un nouveau nœud (`RedNode`/`BlackNode`, l. 210–296).

Hauteur : racine noire, pas deux rouges consécutifs. Avec `bh` = hauteur noire (nombre de nœuds
noirs d'un chemin racine–feuille), un arbre de hauteur noire `bh` a au moins `2^bh − 1` nœuds,
donc **`bh ≤ log2(n+1)`**, et un chemin a au plus `2·bh` nœuds (**hauteur ≤ 2·log2(n+1)**, le
facteur 2 de l'hypothèse de départ). Le modèle actuel comptait une hauteur `log2(n+1)` : c'est la
hauteur moyenne pour des clés aléatoires, pas la hauteur garantie.

Nombre de nœuds écrits (correspondance LLRB ↔ arbre 2-3 : un nœud 2-3 = un nœud noir et au plus
un fils gauche rouge) :
- **put d'une clé nouvelle** : seuls les nœuds 2-3 du chemin de recherche changent ; à chaque
  niveau, soit le nœud 2-3 absorbe la clé remontée (≤ 2 nœuds LLRB recopiés/modifiés, et la
  remontée s'arrête), soit il éclate (les deux moitiés, 2 nœuds ; le milieu remonte et est compté
  au niveau au-dessus) ; au sommet, une nouvelle racine. Donc **nœuds neufs (persistant) ≤ 2·bh + 1**,
  **nœuds anciens modifiés (mutable) ≤ 2·bh** + le nœud créé.
- **put d'une clé existante** : copie du chemin, ≤ 2·bh nœuds.
- **remove (persistant)** : chaque niveau de récursion (≤ `L` niveaux, `L ≤ 2·bh + 1` : la
  descente traverse au plus deux nœuds par niveau noir) laisse au plus 2 nœuds neufs (le nœud
  rendu et son fils hors du chemin ; le fils sur le chemin appartient au niveau suivant), donc
  **≤ 2L ≤ 4·bh + 2**. Simulation : au plus 2·bh + 3 ; la borne est lâche d'un facteur ≈ 2.
- **get/contains** : une itération par nœud du chemin, ≤ 2·bh.

Vérification exhaustive de ces bornes par simulation (`costmodel/tree/llrb_sim.py`, portage fidèle des
algorithmes Java, et `costmodel/tree/experiment.py`) : 1500 clés, ordres aléatoires (3 graines),
croissant, décroissant, zigzag, bit-renversé ; 63 000 opérations, aucune ne dépasse
(`max(k − borne) = 0` pour le put persistant : la borne 2·bh+1 est atteinte).

## 3. CPU + RAM par niveau (code instrumenté)

`costmodel/tree/wcet_gas.py` lit `javap -c -p` du jar **instrumenté par Hotmoka lui-même**
(`moka jars instrument io-takamaka-code-1.8.1.jar … --init`) et calcule, par méthode, le maximum
sur les chemins acycliques de la somme des `charge*` (CPU) et `chargeForRAM*` (RAM), appels
compris (appel virtuel : maximum sur les redéfinitions). Hypothèse de données : clés et valeurs
`BigInteger` < 2^63 (identifiants de jetons, compteurs) : `bitLength ≤ 63`.

| élément (gaz CPU+RAM) | persistant | mutable |
|---|---|---|
| `StorageSupport.compare` (clé BigInteger 63 bits ; objet de stockage : 383) | 458 | 458 |
| cadre de `put(Node,K,V)` sans rotations ni `flipColors` | 2324 | 1909 |
| `rotateLeft` / `rotateRight` / `flipColors` | 770 / 770 / 936 | 446 / 446 / 220 |
| **W_put** = cadre + max(rotL, rotR + flip) (après `rotateLeft`, ni `rotateRight` ni `flipColors` ne sont possibles au même niveau) | **4030** | **2575** |
| `put(K,V)` public (dont `mkRootBlack`, copie de la racine) | 1259 | 277 |
| itération de `get`/`getOrDefault`/`containsKey` | 623 | 623 |
| `get…` public (entrée + 1 itération) | 741 | 741 |
| **W_rm** = max(cadre de `remove(Node,K)`, cadre de `removeMin` + `min`) | **10629** | — |
| `remove(K)` public (sans `containsKey`) / `containsKey(K)` public | 2809 / 730 | |
| `StorageTreeSet` temporaire : W_add / `add` public / `contains` public | | 2566 / 268 / 732 |

Appel depuis le contrat : invoke 8 + enregistrement d'activation 32 + 4×8 = **72**.

## 4. Stockage : octets par nœud (sérialisation Hotmoka)

`costmodel/tree/worst_bytes.py` (via `UpdSize`) sérialise, pour k = 1…40, le pire ensemble de mises à jour :
- persistant : k nœuds neufs formant un sous-arbre connexe contenant la racine (comme toute copie
  de chemin : k−1 liens internes, k+1 liens externes), chaque clé, valeur et fils externe étant un
  objet ancien d'une transaction distincte (hash complet de 32 octets à chaque fois), progressifs
  ≥ 32768 (5 octets), tailles ≥ 32768 (5 octets), classes `RedNode` et `BlackNode` présentes, mise
  à jour de la racine de la carte, `UpdateToNull` ;
- mutable (insertion) : k nœuds anciens dont tous les champs qu'une insertion peut changer
  (couleur, taille, gauche, droite) changent, vers des objets distincts, + le nœud créé + la racine.

Résultat exact : **persistant ≤ 372 + 148·k octets**, **mutable ≤ 232 + 130·k octets**
(incréments constants 148 et 130 ; la constante contient les 1res occurrences : hash de la
transaction courante, jar Takamaka, signatures des 5 champs, deux noms de classe, carte).
Une valeur ou clé `BigInteger` < 2^63 coûte moins qu'une référence (vérifié : 92 contre 122 octets
pour un update isolé).

## 5. Bornes dérivées (gaz, avec bh ≤ log2(n+1))

- **map_get** : 741 + 72 + 623·2·bh → `813 + 1246·log2(n+1)`.
- **map_put** (persistant, pire que mutable) :
  CPU/RAM ≤ 1259 + 72 + 4030·(2bh+1) ; stockage ≤ 80·(372 + 148·(2bh+1)) ;
  total `46961 + 31740·log2(n+1)` (mutable : `21484 + 25950·log2(n+1)`, en dessous).
  Le `ub` de `map_put` ajoute déjà `C_NEW` = 27179 : `C_TREEW0 = 46961 − 27179 = 19782`.
- **map_remove** (persistant) : CPU/RAM ≤ 2809 + 730 + 72 + 623·2bh + 10629·(2bh+1) ;
  stockage ≤ 80·(372 + 148·(4bh+2)) ; total `67680 + 69864·log2(n+1)`. Nouvelles constantes
  `C_TREER0/1` (la forme de `hotmoka_gas.pl.in` change pour `map_remove` seulement).
- **tmp_get/tmp_put** (`StorageTreeSet` temporaire, jamais stocké : pas de stockage) :
  `max(268 + 72 + 2566, 732 + 72) + max(2·2566, 2·623)·log2(n+1)` = `2906 + 5132·log2(n+1)`.

Les intercepts gardent le maximum avec l'ancienne valeur (enveloppes de microbenchmarks qui
contiennent aussi le travail de l'appelant) : seul `C_TREE0` reste à 1363.8 (dérivé 813).

| constante | avant (ajustée) | après (dérivée) |
|---|---|---|
| C_TREE0 | 1363.8 | 1363.8 (dérivé 813) |
| C_TREE1 | 243.4 | 1246 |
| C_TREEW0 | 1774.9 | 19782 |
| C_TREEW1 | 11603 | 31740 |
| C_TREER0 | (= C_TREEW0) | 67680 |
| C_TREER1 | (= C_TREEW1) | 69864 |
| C_TMP0 | 464.8 | 2906 |
| C_TMP1 | 991.4 | 5132 |

Les autres constantes (`C_TX`, `C_NEW`, …) sont inchangées.

## 6. Hypothèses et limites

- clés/valeurs `BigInteger` < 2^63 ; clés objets de stockage non `Comparable` (cas du corpus :
  `Contract`, `PayableContract`) — une clé `Comparable` exécuterait son `compareTo` ;
- `map_remove` est borné pour les arbres persistants (les seuls `remove` du corpus : ERC721
  `tokenApprovals`, SimpleSharedEntity `shares`/`offers`). `StorageTreeMap.removeMin` (mutable,
  l. 374–383) **ignore le résultat de `h.balance()`** (Sedgewick : `return balance(h)`) : après
  une rotation, l'arbre mutable peut être corrompu ; la simulation lève alors une exception
  (`NullPointerException` attendue aussi en Java). Hors corpus, signalé seulement ;
- les bornes `lb` des primitives d'arbre utilisent les mêmes constantes et ne sont donc pas des
  bornes inférieures sûres (le pipeline ne les vérifie pas) ;
- la borne par primitive compte à chaque appel les 1res occurrences (hash de transaction, jar,
  signatures de champs) : une opération qui fait plusieurs accès paie ces octets plusieurs fois
  dans la borne, une seule fois en réalité.

## 7. Confrontation aux mesures

`pipeline/run_pipeline.py` (modèle régénéré avec `constants_moka_sur.json`), 14 contrats,
36 opérations, état du DSL au moment de la dérivation (les ajustements ultérieurs du DSL ont changé
quelques bornes ; voir le README pour les résultats actuels).

| gaz mesuré | points au-dessus (avant : constantes ajustées) | après | médiane des ratios médians borne/mesuré (avant → après) | ratio max (avant → après) |
|---|---|---|---|---|
| référence `data/bench_moka.csv` | 0 / 3312 | **0 / 3312** | 1,67 → 2,38 | 46,8 → 224,7 |
| remesure complète (nœud neuf, autres adresses) | **3** / 3312 (`example_coin.mint.T`) | **0 / 3312** | 1,68 → 2,38 | 45,5 → 218,7 |
| remesure ciblée (coin, erc721, crypto_buddy, crypto_shark ; nœud neuf) | — | **0 / 1200** | — → 2,84 | — → 5,52 |

Aucun point mesuré ne dépasse la dérivation : pas de terme manquant à chercher.

Largeur. Sur les opérations d'arbre ERC20/ERC721, le ratio médian passe de 1,2–2,0 à 1,7–4,5
(`mint` : 1,22 → 1,98 ; `transferFrom` ERC721 : 1,98 → 4,25). L'écart vient de trois facteurs
pire cas qui se cumulent et que les mesures n'atteignent pas :
1. hauteur garantie `2·log2(n+1)` au lieu de la hauteur réelle (simulation, n = 1500 : hauteur 14
   en ordre aléatoire, 15 en ordre croissant, contre 21,1 garanti ; le nombre de nœuds écrits
   suit le chemin effectivement restructuré, souvent bien plus court) ;
2. octets pire cas par nœud (hash de 32 octets distinct par référence, progressifs et tailles sur
   5 octets) alors qu'en pratique beaucoup de références d'une même réponse sont partagées (1 octet) ;
3. `remove` : borne `4·bh+2` nœuds contre `2·bh+3` au plus en simulation, et 1res occurrences
   comptées à chaque primitive (un `transferFrom` en enchaîne 5 à 7).
Les ratios très grands viennent de bornes CiaoPP où la constante d'arbre multiplie une taille :
`simple_shared_entity.*.F` (152, 177 : terme `69864·length(Of0)·log2(length(Of0)+1)`, un `remove`
par offre parcourue) et `ballot.delegate.L` (225 : terme
`2·C_TMP1·log2(∏(i+1))`, ensemble temporaire de la chaîne de délégation). Ce sont des bornes de forme correcte mais très au-dessus du cas mesuré ; elles restent
sûres.
