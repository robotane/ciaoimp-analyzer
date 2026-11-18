# caslog_prep : contrat Hotmoka (DSL impératif Ciao) vers fichier CasLog

Un seul pilote Ciao Prolog, `caslog_prep.pl`, chargé dans `ciaopp -T`. Il charge le
contrat, lance `analyze(shfr)` et `analyze(eterms)` (pas d'analyse de coût), puis écrit
un fichier prêt pour CasLog :

1. les primitives de `hotmoka_caslog_prims.pl` (fichier fixe : `hotmoka.pl` réécrit avec
   des coupures au lieu de `->`, avec `mode`/`measure` écrits à la main) ;
2. `:- mode` et `:- measure` de chaque prédicat du contrat, déduits de CiaoPP ;
3. les clauses développées (comme `clean_print.pl`), où les unifications `X = Y` sont
   éliminées par liaison quand c'est sûr.

Sont exclus : les regtypes/props (`balances/1`, `addrs/1`...), `goal/N`, `goal_chain/N`.

## Commande

Depuis la racine de ciaoimp-analyzer :

```sh
tools/caslog_prep/run.sh gradual_ponzi
```

Le script lance `ciaopp -T` avec `caslog_prep.pl` sur `data/contracts_hotmoka/gradual_ponzi.pl`,
puis CasLog, et affiche les fonctions de temps. Il écrit dans `build/caslog_prep/`
(ignoré par git) : `gradual_ponzi_caslog.pl` (entrée CasLog) et `gradual_ponzi_caslog.out`
(sortie complète de CasLog). Un second argument change le dossier de sortie, la variable
`CASLOG` le chemin de CasLog. Un seul processus à la fois, mémoire limitée à 2 Go.

`clean_print.pl` (24 lignes) est la version minimale : il écrit seulement les clauses
développées, sans annotations.

`caslog_prep/2` accepte un second argument : le fichier de primitives (par défaut
`hotmoka_caslog_prims.pl` de ce répertoire ; `run.sh` le passe explicitement).
Le fichier produit commence par des commentaires `% entry: f/N` (méthodes publiques) et
se termine par `% unifications kept` / `% undefined predicates` s'il reste des problèmes.

## Comment sont déduits mode et measure

- **mode** : pour chaque prédicat, toutes les versions de `complete/7` du domaine shfr
  (`get_completes/4` de `ciaopp/src/infer/infer.pl`, puis `asub_to_info/5` de
  `plai/domains`). Un argument est `-` s'il est libre (`var/1`) dans au moins une version,
  sinon `+`. Un argument constant dans l'appel (venant de `goal/1`) n'est pas une preuve.
  Les appels de `goal/1` rendent parfois ground un argument de sortie (`Ok = 1`) : « libre
  dans une version » l'emporte, l'entrée `var(Ok)` le confirme.
- **measure** : types eterms (`get_info(regtypes, pred, ...)`) traduits par
  `type2measure/3` (`infer.pl` : liste -> `length`, nombre -> `int`, reste -> `void`).
  Type d'appel pour `+`, type de succès pour `-`, l'autre en repli. Une mesure encore
  `void` est complétée par la structure des clauses : argument de tête liste/entier, ou
  variable passée à un appelé de mesure connue (point fixe). Un compteur (`I1 is I+1`
  repassé à l'appel récursif) passe à `void` : CasLog ne sait pas borner sa taille.
- **unifications** : `X = Y` éliminée en liant X et Y si (a) c'est le premier but, ou
  (b) aucune coupure ne précède et aucun but précédent ne compare la variable (`==`,
  `\==`), ou (c) une coupure précède mais la variable est locale (ou argument de tête
  libre) et n'apparaît pas avant. Sinon elle est gardée et signalée. Hypothèse : clauses
  pures (les effets `store/emit/load` n'ont pas de lien avec les variables).

## Résultats

Validation `gradual_ponzi` : les fonctions de temps sont identiques à la référence faite
à la main (`invest/6 [4*($5*$3)+4*$5+9*$3+9]`, `invest$for1/4`, primitives idem). Les `mode`/`measure`
et les clauses du contrat sont identiques à celles de `gradual_ponzi_caslog.pl` ; seules les
primitives supplémentaires (map_get, arr_get...) s'y ajoutent.

Les 14 contrats passent CasLog sans erreur. Fonctions de temps des méthodes publiques
(`$i` = taille du i-ème argument : longueur de liste ou entier) :

| contrat | CasLog | méthodes publiques |
|---|---|---|
| ballot | oui | `give_right/5` `[2*$4+6]`<br> `vote/6` `[3*$5+2*$3+12]`<br> `delegate/6` `[inf]`<br> `winner/2` `[4*$1+2]`<br> |
| blind_auction | oui | `bid/9` `[inf]`<br> `reveal/15` `[inf]`<br> `auction_end/9` `[4*$7+9]`<br> |
| crowdfunding | oui | `new_campaign/5` `[2*$3+5]`<br> `contribute/7` `[inf]`<br> `check_goal_reached/6` `[4*$4+3*$2+11]`<br> |
| crypto_buddy | oui | `token_transfer/5` `[4*$4+11]`<br> `approve/7` `[$6+2*$4+8]`<br> `transfer_from/10` `[2*$9+3*$7+4*$5+21]`<br> |
| crypto_shark | oui | `mint/8` `[2*$7+2*$5+8]`<br> `approve/8` `[$8+$7+$5+$4+7]`<br> `set_approval_for_all/7` `[$6+2*$4+7]`<br> `transfer_from/12` `[$12+$11+2*$9+4*$7+3*$5+20]`<br> |
| distributor | oui | `add_as_payee/3` `[$2+2]`<br> `distribute/6` `[4*($5*$4)+9*$5+8*$4+15]`<br> |
| example_coin | oui | `token_transfer/5` `[4*$4+10]`<br> `mint/8` `[2*$5+7]`<br> `burn/8` `[2*$5+7]`<br> |
| example_erc721 | oui | `mint/8` `[2*$7+2*$5+8]`<br> `transfer_from/12` `[$12+$11+2*$9+4*$7+3*$5+20]`<br> |
| gradual_ponzi | oui | `invest/6` `[4*($5*$3)+4*$5+9*$3+9]`<br> |
| simple_auction | oui | `bid/10` `[8*$9+15]`<br> `auction_end/9` `[4*$7+9]`<br> |
| simple_ponzi | oui | `invest/8` `[8*$7+14]`<br> |
| simple_pyramid | oui | `invest/8` `[4*($7*$3)+4*$7+9*$3+10]`<br> |
| simple_shared_entity | oui | `place/10` `[exp($5,2)+4*$9+9*$5+2*$4+15]`<br> `accept/12` `[exp($6,2)+8*$10+6*$6+6*$4+34]`<br> |
| tictactoe | oui | `play/17` `[20*$16+23*$14+70]`<br> |

## Limites (les `inf`)

- `delegate/6` (ballot) : `follow/6` fait grandir un accumulateur (`Seen`) pendant que la
  liste diminue ; la récurrence à deux variables dépasse CasLog (1992).
- `bid/9`, `reveal/15` (blind_auction) : la valeur lue dans une table (`map_get`) est une
  liste dont la taille n'est liée à aucun argument.
- `contribute/7` (crowdfunding) : liste (`funders`) extraite d'un terme `campaign(...)`
  lui-même extrait d'une liste ; CasLog ne suit pas les tailles des champs.
- Comparaison avec les bornes de gas de CiaoPP (`results/ciaopp_cost_normalized_hotmoka_results.txt`,
  autre jeu de contrats normalisés) : même classe quand il n'y a que du parcours de liste
  (gradual_ponzi/simple_pyramid : linéaire en la liste des investisseurs). CasLog compte les
  tables comme des listes (linéaire en leur taille) alors que le gas de CiaoPP les compte en
  `log` : les coûts `log(taille de table)` de CiaoPP deviennent linéaires ici.
  Les contrats à entrées constantes (simple_ponzi, simple_auction) sont linéaires en la liste
  des soldes ici contre une constante en gas. `simple_shared_entity` est quadratique ici et
  produit/log côté gas.
- Les tests de type des helpers (`atom/1`, `integer/1`) sont modélisés par un pas chacun.
