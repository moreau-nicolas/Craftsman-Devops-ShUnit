# Craftsman + DevOps = shUnit

Je présente ici l'utilisation de shUnit2 sur un cas concret. Ce projet est utilisé pour des talks/BBL/...

Pour avoir suivi le mouvement CraftsmanShip depuis ses débuts, et être à présent dans le DevOps, lorsque j'arrive sur un projet je gardes les mêmes réflexes. Lorsque je dois intervenir sur du code, je commence par écrire des tests si il n'y en a pas. Ceci me permet de ne pas avoir de régressions.
Lorsque j'ai commencé à intervenir sur des scripts de déploiement, j'ai toujours été surpris par le peu de tests existants.
Ceci est donc mon retour d'expérience dans le cas de scripts shell qui tâchent.

J'utilise la librairie [shUnit2](https://github.com/kward/shunit2)

Dans la suite, tout ce qui est **[Step_X]** indique la branche à utiliser à chaque fin d'étape pour la correction.

## Installation

Installer shUnit2:
```shell
sudo apt install shunit2
```
/!\ Debian = version 2.1.6

## Sous le capot:

Quand shunit est *sourcé*, il va:
* Parcourir toutes les functions qui commencent par **test** et les ajouter à sa liste de tests.
* Avant d'éxécuter les tests, il va exécuter la function **oneTimeSetUp()**, à la fin de tous les tests, il pourra exécuter **oneTimeTearDown()**.
* Avant chaque test, il va exécuter la funtion **setUp()**, et après chaque test, il va exécuter **tearDown()**.
* À la fin, il va générer un rapport

shunit fournit toute une [suite d'assertions](https://github.com/kward/shunit2#-asserts): assertEquals, assertNotEquals, assertSame, assertNotSame, assertContains, assertNotContains, assertNull, assertNotNull, assertTrue, assertFalse

Shells supportés, [voir relase note 2.1.8](https://github.com/kward/shunit2/blob/master/doc/RELEASE_NOTES-2.1.8.md):
* sh
* ash
* bash
* ksh
* pdksh
* zsh (voir [known bugs and issues 2.1.8](https://github.com/kward/shunit2/blob/master/doc/RELEASE_NOTES-2.1.8.md#known-bugs-and-issues))

## Mon premier shUnit

Créer le script test:
```bash
nano tests/test_install_trainee_environment.sh
```

```bash
#!/usr/bin/env bash

set -o nounset
# set -o xtrace

# Set magic variables for current file & dir
__dir_tst="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root_tst="$(cd "$(dirname "${__dir_tst}")" && pwd)" # <-- change this as it depends on your app


SCRIPT_PATH="${__root_tst}/install_trainee_environment.sh"

test_should_be_successfull() {
  assertTrue "[ 0 -eq 0 ]"
}

# Eat all command-line arguments before calling shunit2.
shift $#
# Load shUnit2.
source "$(which shunit2)"
```

Exécuter les tests:
```bash
./tests/test_install_trainee_environment.sh
```

**[Step_0]**

### Exécuter un seul test

```shell
./tests/test_install_trainee_environment.sh -- test_should_be_successfull
```

Si shUnit est sourcé dans le script, il faut ajouter avant le source:
```shell
# Eat all command-line arguments before calling shunit2.
shift $#
# Load shUnit2.
source "$(which shunit2)"
```

## Préparer le script à être testable

Créons le premier test du notre script:
```shell
test_should_failed_without_parameters() {
  local result=$(source "${SCRIPT_PATH}" 2>&1)
  local code=$?

  printf "${result}"
  assertEquals "Wrong return code" '0' "${code}"
}
```
Si le test est exécuter avec le script actuelle, le test est en erreur, car les options à passer au script sont contrôlées.

Pour pouvoir tester les functions unitairement, en fonction du script, il y a plusieurs solutions:
1. ajouter une condition autour du bloc principal:
```shell
if [ "${1}" != "--source-only" ]; then
    <BLOC MAIN>
fi
```
2. gérer un nouvel argument *--source-only*:
```shell
    "--source-only")
        return 0
        ;;
```

Le test est mis à jour:
```shell
test_should_failed_without_parameters() {
  local result=$(source "${SCRIPT_PATH}" --source-only 2>&1)
  ...
```

**[Step_1]**

## Tester les retours attendus

Le test **test_should_failed_without_parameters** n'est pas satisfaisant en l'état, car il ne reflète pas l'intention du test: il doit être en erreur sans paramètre passé à la commande.

Il faut donc tester le retour de la commande en erreur dans un assert
```shell
test_should_failed_without_parameters() {
  local result=$(source "${SCRIPT_PATH}" 2>&1)
  local code=$?

  assertEquals 'Wrong usage message' 'Usage:
 install_trainee_environment [Option]

 Options:
 - create: create cluster, reverse proxy, trainees namespaces,
           add helm charts, and display trainees infos
 - create_rp: create reverse proxy
 - add_helm: add helm charts to cluster
 - create_ns: create trainees namespaces in cluster
 - delete_ns: delete trainees namespaces in cluster
 - delete_rp: delete reverse proxy
 - delete_cl: delete cluster
 - delete_pj: delete project
 - delete: delete reverse proxy and delete clsuter (in this order)
 - get_cred: init kubectl
 - info: display trainees infos
 - -h, --help: display this help message' "${result}"
  assertEquals "Wrong return code" '0' "${code}"
}
```

Cet assert ne fonctionne pas!
Il y a des espace en fin de ligne dans le message d'utilisation... :(
Solution: supprimer les **' \n'** du script d'origine

Amélioration: mettre le message attendu dans un fichier extern.
```shell
nano tests/expected/usage_message.txt:
```

```txt
Usage:
 install_trainee_environment [Option]

 Options:
 - create: create cluster, reverse proxy, trainees namespaces,
           add helm charts, and display trainees infos
 - create_rp: create reverse proxy
 - add_helm: add helm charts to cluster
 - create_ns: create trainees namespaces in cluster
 - delete_ns: delete trainees namespaces in cluster
 - delete_rp: delete reverse proxy
 - delete_cl: delete cluster
 - delete_pj: delete project
 - delete: delete reverse proxy and delete clsuter (in this order)
 - get_cred: init kubectl
 - info: display trainees infos
 - -h, --help: display this help message
```
```bash
  assertEquals 'Wrong usage message' "$(cat tests/expected/usage_message.txt)" "${result}"
```

**[Step_2]**

## Bouchonner les commandes

La function *get_cluster_credentials* va être testée, car elle ne contient qu'une seule commande.
```shell
test_get_cluster_credentials_should_be_successful() {
  source "${SCRIPT_PATH}" --source-only
  # workaround: disable 'set -o errexit'
  set +e
  result=$(get_cluster_credentials)
  code=$?

  assertEquals "Wrong return code" '0' "${code}"
}
```

Sauf que ....
```shell
Fetching cluster endpoint and auth data.
ERROR: (gcloud.container.clusters.get-credentials) ResponseError: code=403, message=Project lookup error: permission denied on resource 'projects/formation-ci-laurent' (or it may not exist).
```

Il faut donc bouchonner la commande **gcloud**.
```shell
# Mock "gcloud" command
# save command line in gcloud_log file
# this function has behavior depending on the command line.
gcloud() {
  echo "${FUNCNAME[0]} $*" >> gcloud_log
}
```
Je sauvegarde le résultat de la commande dans un fichier, que j'ajoute dans mes assertions pour vérifier que la bonne commande a été appelée.

Afin de garder mon espace de travail propre, je supprime ce fichier dans la phase de tearDown:
```shell
tearDown() {
  rm -f gcloud_log
}
```

Ajout de l'assertion qui permet de valider le bon format de la commande:
```shell
assertEquals 'Wrong gcloud cmd' 'gcloud container clusters get-credentials formation-ci --region europe-west1 --project formation-ci-laurent' "$(cat gcloud_log)"
```

**[Step_3]**

## Capturer les outputs

Dans un script, des messages sont affichés dans la console pour que la personne qui l'exécute puisse suivre ce qu'il se passe.
Ces messages sont à capturer, car ils indiquent la bonne exécution du process.
Les messages émis par la commande ou la fonction sont déjà capturés dans la variable **result**:
```shell
  result=$(get_cluster_credentials)
```

Une assertion va être ajoutée dans le test *test_get_cluster_credentials_should_be_successful* pour vérifier ces messages:
```shell
  assertEquals 'Wrong result' '## Get credentials laurent' "${result}"
```

**[Step_4]**

## Gérer les variables d'environnements du script

Le script à tester utilise implicitement une variable d'environnement: ${USER}
```shell
echo ${USER}
```
Cette variable utilise le nom de l'utilisateur courant exécutant le script.

Dans une CI, celle-ci risque d'être différente, voir inexistante. Il faut donc *stabiliser* ce comportement en forcant cette variable.
Pour cela, il suffit de passer une variable ayant le même nom lors de l'appel de la fonction ou du source du script.

Dans notre script cette variable d'environnement est utillisée pour initialiser une variable globale, il faut donc passer cette variable à moment où l'on source le script:
```shell
  USER=static_user source "${SCRIPT_PATH}" --source-only
```
L'assertion est à mettre à jour avec ce nouvel utilisateur:```shell
assertEquals 'Wrong gcloud cmd' 'gcloud container clusters get-credentials formation-ci --region europe-west1 --project formation-ci-static_user' "$(cat gcloud_log)"
```

Et cette variable est aussi affichée dans un message lors de l'appel de la function, il suffit de la passer lors de l'appel:
```shell
  result=$(USER=other_user get_cluster_credentials)
```
L'assertion est à mettre à jour avec ce nouvel utilisateur:
```shell
  assertEquals 'Wrong result' '## Get credentials other_user' "${result}"
```

**[Step_5]**

## Simuler les retours et les codes retours

### Connaitre les retours des commandes

Dans le script, seulement 3 commandes ont leur retour qui est capturé pour être traité.
Voici les commandes avec leur retour:
```shell
$ gcloud organizations list --filter="DISPLAY_NAME=zenika.com" --format="value(ID)"
10000000000
```

```shell
$ gcloud alpha billing accounts list --filter="NAME:Zenika" --format="value(ACCOUNT_ID)"
AAAAAA-BBBBBB-CCCCCC
```

```shell
kubectl get service reverse-proxy -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
127.0.0.1
```

Ces retours vont être simulés.

### Application avec le test de la function *create_cluster*

Il faut donc commencer avec la base de notre test:
```shell
test_create_cluster_should_be_successful() {
  source "${SCRIPT_PATH}" --source-only
  # workaround: disable 'set -o errexit'
  set +e
  result=$(create_cluster)
  code=$?

}
```
Puis ajouter les assertions que nous savons faire:
* assertion sur le code retour:
```shell
  assertEquals "Wrong return code" '0' "${code}"
```
* assertion sur ce qui est envoyé dans la sortie standard, en lisant le code:
```shell
  assertEquals 'Wrong result' '## Create project formation-ci-static_user
## Associate project formation-ci-static_user and billing account
## Enable container.googleapis.com API
## Create cluster formation-ci' "${result}"
```
* assertion sur les commandes utilisées, toujours en lisant le code:
```shell
  assertEquals 'gcloud config unset project
gcloud organizations list --filter=DISPLAY_NAME=zenika.com --format=value(ID)
gcloud projects create formation-ci-static_user --organization=${orga}
gcloud alpha billing accounts list --filter=NAME:Facturation Zenika --format=value(ACCOUNT_ID)
gcloud alpha billing projects link formation-ci-static_user --billing-account ${billing_id}
gcloud services enable container.googleapis.com --project formation-ci-static_user
gcloud container clusters create formation-ci --region europe-west1 --project formation-ci-static_user --preemptible --machine-type e2-standard-8 --num-nodes 1 --min-nodes 0 --max-nodes 3 --enable-autorepair --enable-autoscaling' "$(cat gcloud_log)"
```

Le test unitaire est en erreur, car il manque les valeurs pour les variables ${orga} et ${billing_id}, nous allons donc les boucher à partir des résultats vu précédemment. Des comportements vont être ajoutés à la méthode bouchon **gcloud**:
```shell
gcloud() {
  echo "${FUNCNAME[0]} $*" >>gcloud_log

  case "$*" in
    'organizations list --filter=DISPLAY_NAME=zenika.com --format=value(ID)')
      printf "10000000000"
      return 0
      ;;
    'alpha billing accounts list --filter=NAME:Zenika --format=value(ACCOUNT_ID)')
      printf "AAAAAA-BBBBBB-CCCCCC"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}
```

Et il faut remplacer les chaines ${orga} et ${billing_id} de l'assertion par les valeurs retournées:
```shell
  assertEquals 'gcloud config unset project
gcloud organizations list --filter=DISPLAY_NAME=zenika.com --format=value(ID)
gcloud projects create formation-ci-static_user --organization=10000000000
gcloud alpha billing accounts list --filter=NAME:Facturation Zenika --format=value(ACCOUNT_ID)
gcloud alpha billing projects link formation-ci-static_user --billing-account AAAAAA-BBBBBB-CCCCCC
gcloud services enable container.googleapis.com --project formation-ci-static_user
gcloud container clusters create formation-ci --region europe-west1 --project formation-ci-static_user --preemptible --machine-type e2-standard-8 --num-nodes 1 --min-nodes 0 --max-nodes 3 --enable-autorepair --enable-autoscaling' "$(cat gcloud_log)"
```
**[Step_6]**

# Usages avancés

## Les suites de tests

```shell
my_test1() {
  assertTrue "[ 0 -eq 0 ]"
}
my_test2() {
  assertTrue "[ 0 -eq 0 ]"
}

suite() {
  suite_addTest my_test1
  suite_addTest my_test2
}
```
Attention, cela surcharge le comportement de découverte des tests qui sont préfixés par *test*. Il faudra alors les ajouter dans la suite.

**[Step_7]**

## Usage de skip

Les functions **startSkipping** et **endSkipping** permettent de passer des assertion/fails des tests, mais qui seront comptabilisés:

```shell
test_skippy() {
  assertTrue "[ 0 -eq 0 ]"
  startSkipping
  assertTrue "[ 0 -eq 1 ]"
  endSkipping
  assertTrue "[ 0 -eq 0 ]"
}
```

**[Step_8]**

## Asserts avec numéros de ligne

```shell
test_line_nb() {
    ${_ASSERT_EQUALS_} "'not equals'" 1 2
    assertEquals 'not equals' 1 2
}
```
Attention: dans le cas de **${_ASSERT_EQUALS_}**, il faut doubler les quotes autour des chaines de caractères.

**[Step_9]**

## Les trucs qui perturbent shUnit2:

Si un script contenant *set -o errexit* ou *set -e* est sourcé dans un test, shUnit2 fait cette erreur:
```
ASSERT:Unknown failure encountered running a test
```
La solution de contournement est de faire un *set +e* sur après le source
```bash
test_with_source() {
  echo "${SCRIPT_PATH}"
  source "${SCRIPT_PATH}" --source-only
  # workaround: disable 'set -o errexit'
  set +e
  ...
}
```

Ne jamais bouchonner certaines commandes de base comme *chmod*, car elles peuvent être utilisées dans le fonctionnement interne de shUnit2. (j'en ai fait les frais)

# Sources:

* https://alexharv074.github.io/2018/09/07/testing-aws-cli-scripts-in-shunit2.html
* https://alexharv074.github.io/2017/07/07/unit-testing-a-bash-script-with-shunit2.html
* https://www.leadingagile.com/2018/10/unit-testing-shell-scriptspart-one/
* https://www.leadingagile.com/2018/10/unit-testing-shell-scriptspart-two/
* https://www.leadingagile.com/2018/10/unit-testing-shell-scriptspart-three/
