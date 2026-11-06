# Points à revoir

Les notions qui m'ont posé problème pendant les séances, même quand je les ai comprises ensuite.
Pour chaque point : la confusion de départ, puis l'explication à retenir.

---

## Jour 1 : Azure Container Registry (3-4 novembre 2026)

### Azure : compte, tenant, abonnement

- **Confusion :** `az login` affichait « No subscriptions found » alors que je pensais avoir créé un compte.
- **À retenir :**
  - **Compte** = mon identité (mon adresse e-mail de connexion).
  - **Tenant** = l'annuaire Entra ID qui contient cette identité. Un compte peut appartenir à plusieurs tenants.
  - **Abonnement** = le conteneur de facturation des ressources. Un tenant peut avoir 0, 1 ou plusieurs abonnements.
  - L'inscription au compte gratuit n'avait jamais été terminée. Le compte gratuit (200 $ sur 30 jours) n'est accordé **qu'une fois par personne** (vérification de l'e-mail, du téléphone et de la carte), d'où le passage au paiement à l'utilisation.

### Budget Azure et portée (scope)

- **Confusion :** je ne trouvais pas l'abonnement dans le panneau « Sélectionner la portée » ni dans la liste des abonnements.
- **À retenir :**
  - Hiérarchie : **compte de facturation → groupe d'administration (Tenant Root Group) → abonnement → resource group**.
  - Le menu *Budgets* se trouve **à l'intérieur** de l'abonnement : Abonnements → cliquer sur l'abonnement → Gestion des coûts → Budgets.
  - ⚠️ Un budget **envoie seulement des alertes, il ne coupe rien**. Les données de coût arrivent avec plusieurs heures de retard.

### Les terminaux

- **Confusion :** `az` et `dotnet` étaient introuvables. `$env:...` ne fonctionnait pas. Je ne savais pas si je devais utiliser l'icône `>_` du portail.
- **À retenir :**
  - L'icône `>_` du portail = **Cloud Shell**, un terminal dans Azure, qui **ne voit pas mes fichiers locaux**. Pour le lab, j'utilise le terminal local.
  - Un terminal lit le **PATH au démarrage**. Après une installation, il faut **ouvrir un nouveau terminal**.
  - Mon terminal VS Code est **MSYS2 bash**, qui n'hérite par défaut que d'un PATH minimal. Corrigé avec `MSYS2_PATH_TYPE=inherit` dans les paramètres VS Code.
  - La syntaxe dépend du terminal :

    | PowerShell | Bash (Git Bash / MSYS2) |
    |---|---|
    | `$env:NOM = "valeur"` | `export NOM=valeur` (sans espaces) |

  - Si un collage dans le terminal ajoute `[200~` ou `~` devant la commande (*bracketed paste*), le bash a mal interprété le collage. Solution : `echo 'set enable-bracketed-paste off' >> ~/.inputrc`, puis ouvrir un nouveau terminal.
  - `az login` pose une question (le choix d'abonnement) : il faut **y répondre avec Entrée** avant de taper d'autres commandes.
  - Ouvrir le terminal dans VS Code : menu **Terminal → New Terminal**. `Ctrl+ù` ou `Ctrl+/` peuvent **mettre une ligne en commentaire** par erreur, et `Ctrl+Z` l'annule.

### API avec controllers vs Minimal API

- **Confusion :** je croyais que le squelette était une Minimal API.
- **À retenir :**
  - **Minimal API** = les routes sont écrites dans `Program.cs` avec `app.MapGet(...)`, sans classe.
  - **Controllers** = une classe `: ControllerBase` avec `[ApiController]`, et des méthodes décorées de `[HttpGet("...")]`. `Program.cs` se contente de faire `AddControllers()` et `MapControllers()`.

### Écrire une action de controller

- **Confusion :** les méthodes « étaient déjà écrites », je ne savais pas quoi faire. Je pensais renvoyer avec `Console.WriteLine`. J'ai écrit le JSON dans une chaîne de caractères. Je pensais qu'`Ok()` enlevait le code 200.
- **À retenir :**
  - `return StatusCode(501, "TODO");` = la méthode existe mais renvoie l'erreur **501 Not Implemented**. Il fallait la remplacer par le vrai code.
  - `Console.WriteLine` écrit dans les **logs du serveur**. Le client ne voit que ce que la méthode **`return`**.
  - `Ok(...)` = raccourci de `StatusCode(200, ...)`. Autres raccourcis : `NotFound()` (404), `BadRequest()` (400).
  - On **n'écrit jamais le JSON à la main** : on renvoie un **objet C#**, et ASP.NET le convertit.
    ```csharp
    return Ok(new { status = "ok" });   // donne {"status":"ok"}
    ```
    `new { ... }` = un **objet anonyme**, un objet créé sans écrire de classe.
  - Un `return` **termine** la méthode. Le code placé après ne s'exécute jamais (code mort).
  - `x ?? "défaut"` = « si x est null, prends "défaut" ». C'est l'équivalent d'un `if (x == null)`.

### Variables d'environnement et secrets

- **Confusion :** où trouver `DB_PASSWORD` ? Faut-il la déclarer ? Où va chercher `Environment.GetEnvironmentVariable` ? « Tu viens de déclarer une variable password ! »
- **À retenir :**
  - `Environment.GetEnvironmentVariable("DB_PASSWORD")` lit la **liste des variables d'environnement** que le programme reçoit au démarrage :
    - sur mon PC : les variables **Windows** (utilisateur et système, celles de la fenêtre « Variables d'environnement »), **plus** celles créées dans le terminal qui lance le programme (`export` / `$env:`) ;
    - dans Azure (conteneur Linux) : les `ENV` du Dockerfile et les variables ou secrets injectés par Container Apps (Key Vault).
  - Si la variable n'existe pas, la méthode renvoie **`null`**.
  - Il faut distinguer deux choses :
    - ❌ `string password = "SuperSecret123";` = écrire **la valeur du secret** dans le code. **Interdit.**
    - ✅ `string password = Environment.GetEnvironmentVariable("DB_PASSWORD");` = une variable C# qui **reçoit** la valeur fournie par l'environnement. Le code ne contient que le **nom**.
  - Un secret ne va **jamais** dans le code ni dans le Dockerfile (`ENV`), car il serait lisible par `docker inspect`.
  - En lisant cette ligne, on comprend : « ce programme attend qu'on lui fournisse un DB_PASSWORD au démarrage ».

### Resource group, fournisseur de ressources, ACR

- **Confusion :** qu'a-t-on enregistré avec `az provider register` avant de créer l'ACR ?
- **À retenir :**
  - **Resource group** = un **dossier** logique, gratuit. Le supprimer supprime tout son contenu.
  - **`az provider register --namespace Microsoft.ContainerRegistry`** = **activer le type de service** ACR sur l'abonnement. Ça se fait une seule fois, c'est gratuit, et ça ne crée rien. L'erreur correspondante est `MissingSubscriptionRegistration`.
  - **`az acr create`** = créer **une vraie instance** de registre (facturée). Après l'enregistrement, on peut en créer autant qu'on veut, chacun étant facturé.
  - Analogie C# : `provider register` = ajouter le package NuGet ; `acr create` = `new ContainerRegistry()`.
  - `az provider register` **demande** l'activation, c'est Azure qui l'effectue, et `az provider show` ne fait que **lire** l'état (`Registering` puis `Registered`).

### Dockerfile, image, conteneur : qui fait quoi

- **Confusion :** l'ACR remplace-t-il Docker ? Le Dockerfile est-il une image ? L'ACR ou ACR Tasks exécute-t-il l'image ?
- **À retenir :**

  | | Analogie C# |
  |---|---|
  | **Dockerfile** = la **recette** (fichier texte) | le code source `.cs` / `.csproj` |
  | **Image** = le résultat construit (mon code et ses dépendances) | le `.dll` publié |
  | **Conteneur** = l'image en cours d'exécution | l'application lancée |

  | Action | Docker | Azure |
  |---|---|---|
  | Construire | `docker build` | **ACR Tasks** (`az acr build`) |
  | Stocker | Docker Hub | **ACR** |
  | Exécuter | `docker run` | **Container Apps** (pas l'ACR) |

  - **ACR Tasks exécute le Dockerfile** (le build), mais **n'exécute pas l'image**.
  - L'ACR ne stocke **pas** le Dockerfile, seulement l'image produite.
  - L'image est **portable** (standard OCI) : on peut aussi la mettre sur Docker Hub ou la lancer avec `docker run`.
  - « Image Docker » n'est pas faux, mais le terme précis (et celui de l'examen) est **image conteneur** (*container image*).

### L'image SDK et le build multi-stage

- **Confusion :** « l'image SDK » est-elle un SDK virtuel, propre à Azure ?
- **À retenir :**
  - `mcr.microsoft.com/dotnet/sdk:10.0` = une image toute prête : **un Linux avec le SDK .NET 10 installé**. C'est le même SDK que sur mon PC, emballé en conteneur. Elle est hébergée sur **MCR** (Microsoft Container Registry), pas spécifiquement sur Azure.
  - **Multi-stage** : l'étape 1 (`sdk`, ~800 Mo) **compile**, l'étape 2 (`aspnet`, ~220 Mo) **exécute**. Seule l'étape 2 est dans l'image finale.
  - À chercher sur YouTube : « Docker multi-stage build .NET », « Dockerfile FROM base image explained ».

### Pourquoi le premier `az acr build` a échoué (.dockerignore)

- **Confusion :** je n'avais pas compris ce qui avait été corrigé.
- **À retenir :**
  - `dotnet run` crée sur mon PC des dossiers de brouillon, `bin/` et `obj/`, qui contiennent des **chemins Windows** (`C:\Program Files\...`).
  - Ils avaient été **envoyés dans le contexte de build**. La machine Linux d'Azure a suivi ces chemins, qui n'existent pas chez elle, et le build a planté **avant** de produire une image. Rien n'est arrivé dans l'ACR.
  - Correction : le `.dockerignore` (la liste noire du contexte de build) exclut `**/bin` et `**/obj`.
  - Principe : une image se construit **uniquement à partir du code source**, jamais à partir de fichiers générés sur un poste.

### Tag, version de l'application, ARG et ENV

- **Confusion :** faut-il modifier le Dockerfile à chaque version ? Le tag `monapp:v2` fait-il afficher « v2 » par l'API ?
- **À retenir :**
  - En temps normal, on **ne modifie pas le Dockerfile** à chaque version : on change le code et on rebuild avec un nouveau tag.
  - Le **tag** est une étiquette posée **à l'extérieur** de l'image, dans l'ACR. **L'application ne le voit pas.**
  - Une image est identifiée de façon unique par son **digest** (`sha256:...`). Plusieurs tags (`v2`, `latest`) peuvent pointer sur le même digest.
  - `latest` n'est **pas** automatique : c'est un tag comme un autre.
  - **Lire un digest** : comparer les premiers caractères suffit (`b66b8…` ≠ `e4bcd…`). Dans mon ACR : `latest` + `v2` → `sha256:b66b8…` ; l'ancienne `v1` → `sha256:e4bcd…` (devenue `tags: null` après l'untag). J'avais d'abord cru que `latest` pointait sur `e4bcd…`.

### Quiz : la géoréplication exige Premium

- **Confusion :** au quiz, j'ai répondu « Standard ou Premium » pour un registre unique servi dans plusieurs régions.
- **À retenir :**
  - « Un seul registre, des copies proches dans plusieurs régions » = **géoréplication** = **Premium uniquement**.
  - Standard ne fait que donner plus de stockage (100 Go) et de débit. Il reste **dans une seule région**.
  - Les mots-clés d'examen qui désignent Premium : géoréplication, plusieurs régions avec un seul registre, Private Link / endpoint privé, clé gérée par le client, rétention des manifests sans tag.

### Quiz : identité managée plutôt que mot de passe

- **Confusion :** au quiz, j'ai répondu « activer le compte admin et mettre son mot de passe dans les secrets ». Je pensais qu'il fallait toujours privilégier un mot de passe stocké dans les secrets.
- **À retenir :**
  - Ranger un mot de passe dans un secret vaut mieux que l'écrire dans le code, mais **le mieux, c'est de ne pas avoir de mot de passe du tout**.
  - **Identité managée** = Azure donne à la ressource (Container Apps) **sa propre identité** dans Entra ID. Azure gère seul les jetons d'accès : aucun mot de passe à stocker, à faire tourner ou à risquer de fuiter.
  - On lui attribue ensuite un **rôle RBAC** sur l'ACR. **AcrPull** = uniquement télécharger les images, ce qui respecte le **moindre privilège**. Owner donnerait beaucoup trop de droits (supprimer le registre, gérer les accès).
  - Le **compte admin** de l'ACR : un seul identifiant partagé, avec tous les droits, et un mot de passe à stocker. Il est désactivé par défaut et n'est pas recommandé.
  - Mots-clés d'examen : « aucun mot de passe / pas d'identifiants stockés » = **identité managée** ; « moindre privilège » pour télécharger des images = **AcrPull** (AcrPush pour envoyer).

### Untag vs delete

- **À retenir :**
  - `az acr repository untag --image monapp:v1` = retire **seulement l'étiquette**. L'image reste stockée (sans tag, `tags: null`) et **toujours facturée**.
  - `az acr repository delete --image ...` = supprime **l'image entière** et **tous les tags** qui pointent dessus.
  - ⚠️ `delete --image monapp:v2` supprimerait **aussi `latest`**, puisque c'est le même digest.
  - `monapp:v2` désigne une image par son **tag**, `monapp@sha256:...` par son **digest**.
  - Nettoyage automatique : la **retention policy** (Premium uniquement) ou `acr purge` via ACR Tasks (tous les SKU).
  - Pour que la version soit la même dans le tag et dans l'application :
    ```dockerfile
    ARG APP_VERSION=dev            # paramètre de la recette, n'existe QUE pendant le build
    ENV APP_VERSION=$APP_VERSION   # recopie la valeur dans l'image, que l'app lira au démarrage
    ```
    ```bash
    az acr build --registry acrai200david --build-arg APP_VERSION=v3 --image monapp:v3 ./jour01-acr/app
    ```
    Analogie C# : `ARG` = paramètre de méthode avec valeur par défaut (`string appVersion = "dev"`), `ENV` = recopier ce paramètre dans une propriété pour qu'il survive (`this.AppVersion = appVersion`).
  - Les différences de comportement entre versions se documentent dans des **release notes** ou un **CHANGELOG**.

---

## Jour 2 : ACR Tasks (5 novembre 2026)

### Écrire un test d'API avec xUnit et WebApplicationFactory

- **Confusion :** j'ai écrit `new HttpClient()` et je ne savais pas comment relier le test à l'API. Les tests, les factories et `async`/`await` sont nouveaux pour moi.
- **À retenir :**
  - `new HttpClient()` crée un client **vide** : il ne connaît aucune adresse et n'est relié à rien. Il ne peut pas appeler mon API.
  - `WebApplicationFactory<Program>` = une **usine** qui démarre mon API **en mémoire** (sans port réseau). C'est l'équivalent ASP.NET du `TestClient` de FastAPI.
  - `_factory.CreateClient()` = « usine, donne-moi un `HttpClient` **déjà branché** sur l'API que tu as démarrée ». Même logique qu'un **Service** qui reçoit son **Repository** par le constructeur : on ne fait pas `new` soi-même, on demande l'objet tout prêt.
  - `IClassFixture<WebApplicationFactory<Program>>` = « xUnit, crée l'usine une fois et passe-la à mon constructeur ». C'est de l'**injection par constructeur**, comme dans mes Services.
  - `await` = « attends le résultat de cette opération longue (un appel HTTP) avant de passer à la ligne suivante ». Une méthode qui utilise `await` doit être marquée `async` et renvoyer `Task`.
  - Le schéma d'un test : **Arrange** (préparer), **Act** (agir), **Assert** (vérifier).
  - `Assert.Equal(attendu, obtenu)` : l'ordre compte, la valeur **attendue** vient d'abord.

### `dotnet test` en local et `az acr run` : deux choses différentes

- **Confusion :** je pensais que `dotnet test tests/MonApp.Tests` avait exécuté le YAML et poussé l'image dans l'ACR.
- **À retenir :**
  - `dotnet test` (sur mon PC) = lance les tests **localement**. Aucun lien avec Azure, ni avec le YAML, ni avec l'ACR. C'est une vérification avant d'envoyer quoi que ce soit.
  - `az acr run --file acr-task.yaml <contexte>` = envoie le dossier à Azure et **exécute le YAML dans le cloud**, sur un agent ACR Tasks.

### Les 3 façons d'utiliser ACR Tasks

- **Confusion :** une task YAML est-elle une alternative à `az acr build` ?
- **À retenir :** oui, ce sont deux façons d'utiliser ACR Tasks, et une troisième s'y ajoute.

  | Commande | Type | Lancement | Push | Équivalent Azure DevOps |
  |---|---|---|---|---|
  | `az acr build` | *Quick task* | À la main | **Automatique** | Un pipeline avec une seule tâche *Docker build & push*, lancé à la main |
  | `az acr run --file x.yaml` | *Quick task* multi-étapes | À la main | **Seulement s'il y a une étape `push`** | *Run pipeline* sur un `azure-pipelines.yml` à plusieurs steps |
  | `az acr task create` | Tâche **enregistrée** | **Automatique** (commit, image de base, timer) | Selon le YAML ou le Dockerfile | Un pipeline enregistré avec `trigger:` ou `schedules:` |

  - `az acr build` = le **raccourci** pour le cas simple (1 image, push automatique).
  - Le YAML sert dès qu'on veut **contrôler** le déroulé : tester **avant** de publier.

### Le fichier `acr-task.yaml` : les mots-clés

```yaml
version: v1.1.0
steps:
  - id: build-tests
    build: -t monapp-tests:$ID --target test .
  - id: run-tests
    cmd: monapp-tests:$ID
  - id: build-image
    build: -t $Registry/monapp:$ID .
  - id: push-image
    push:
      - $Registry/monapp:$ID
```

| Mot-clé | Signification |
|---|---|
| `version: v1.1.0` | Version du format YAML. Elle **active les alias** courts (`$ID`, `$Registry`…). Sans elle, la valeur par défaut est `v1.0.0` et il faut écrire `{{.Run.ID}}`. |
| `steps:` | La liste des étapes, exécutées dans l'ordre. Équivalent des `steps:` d'un job Azure DevOps. |
| `id:` | Le nom de l'étape. Il apparaît dans les logs (`Executing step ID: run-tests`), sert de nom au conteneur, et permet de référencer l'étape dans `when`. |
| `build:` | Type d'étape = **`docker build`**. Construit une image. Accepte toutes les options de `docker build` (`-t`, `-f`, `--target`, `--build-arg`). |
| `cmd:` | Type d'étape = **`docker run`**. **Lance un conteneur** à partir d'une image. Ici, ça exécute les tests. |
| `push:` | Type d'étape = **`docker push`**. Envoie une ou plusieurs images dans le registre. |
| `-t nom:tag` | Le nom et le tag de l'image construite. |
| `--target test` | Construit **seulement jusqu'au stage `test`** du Dockerfile, et non l'image finale. |
| `.` | Le contexte du build = la racine du dossier envoyé. |
| `$Registry` | Alias de `{{.Run.Registry}}` = l'adresse de **mon** registre (`acrai200david.azurecr.io`). Le YAML marche ainsi avec n'importe quel ACR, sans nom codé en dur. |
| `$ID` | Alias de `{{.Run.ID}}` = l'**identifiant unique du run** (`dd4`, `dd5`…). Il sert de tag unique, comme `$(Build.BuildId)` dans Azure DevOps. |
| `$Date`, `$Commit`, `$Branch` | La date du run, et le commit et la branche Git (pour les tasks déclenchées par Git). |
| `when:` | *(non utilisé ici)* Gère les dépendances : `when: ["-"]` = démarre tout de suite, en parallèle ; `when: ["id1"]` = attend l'étape `id1`. **Sans `when`**, chaque étape attend la précédente. |
| `ignoreErrors: true` | *(non utilisé ici)* Marque l'étape comme réussie même en cas d'erreur. À éviter sur une étape de tests. |

- ⚠️ **Une task YAML ne pousse JAMAIS automatiquement**, contrairement à `az acr build`. Sans étape `push`, l'image reste sur l'agent puis disparaît à la fin du run.
- `monapp-tests:$ID` n'a **pas** de `$Registry` devant : cette image n'existe que sur l'agent, pendant le run. Dans les logs, elle apparaît comme `registry.hub.docker.com/library/monapp-tests`, parce qu'un nom sans registre est interprété par convention comme Docker Hub. **Elle n'y a pas été envoyée** : il n'y a pas d'étape `push` pour elle.

### Le Dockerfile à 3 stages (build → test → final)

- **À retenir :**
  - `build` (image SDK) : compile l'app **et** les tests.
  - `test` (`FROM build AS test`) : quand on **lance** cette image, elle exécute `dotnet test`.
  - `final` (image ASP.NET runtime, sans SDK) : l'image **publiée**.
  - L'image finale ne contient pas le SDK, elle **ne peut donc pas lancer `dotnet test`**. D'où le stage `test`, construit avec `--target test`.
  - On a mis un **chemin absolu** dans l'`ENTRYPOINT` du test (`/src/tests/...`), parce qu'ACR Tasks peut changer le répertoire de travail des étapes `cmd` (`/workspace`).

### Code de sortie et arrêt de la task : le garde-fou

- **À retenir :**
  - Chaque programme renvoie un **code de sortie** : **0 = succès**, **autre chose = échec**. `dotnet test` renvoie 1 si au moins un test échoue.
  - Dans une task, si une étape renvoie un code ≠ 0 : `failed to run step ID: run-tests: exit status 1`, puis **la task s'arrête**, et **les étapes suivantes ne s'exécutent pas**.
  - Ce qu'on a vérifié :

    | Run | Tests | Push | Image dans l'ACR |
    |---|---|---|---|
    | `dd4` | ✅ | ✅ | `monapp:dd4` |
    | `dd5` (bug `"ko"`) | ❌ | ⛔ jamais exécuté | **aucune** (`dd5` absent de `show-tags`) |
    | `dd6` (réparé) | ✅ | ✅ | `monapp:dd6` |

  - L'**absence** de `dd5` dans l'ACR est la **preuve** que le garde-fou fonctionne : une version boguée ne peut pas être publiée, ni déployée par erreur.
  - Équivalent Azure DevOps : une tâche *Test* en échec rend le run rouge, et les tâches suivantes (publication de l'artefact) ne s'exécutent pas.

### GitHub ou Azure DevOps pour les déclencheurs de code source ?

- **Confusion :** je pensais que MS Learn ne parlait pas de GitHub, et qu'il fallait n'utiliser que des services Azure.
- **À retenir :**
  - Le module MS Learn dit explicitement : *« ACR Tasks s'intègre à **GitHub et Azure DevOps** »*. Ses exemples de `az acr task create` utilisent même une URL **GitHub** (`--context https://github.com/...#main`).
  - Les deux sont donc au programme. Ce que l'examen évalue, c'est **ACR Tasks** (déclencheur de code source, PAT, webhook, contexte Git), pas GitHub ni Azure DevOps eux-mêmes.
  - Les droits du PAT diffèrent selon la plateforme :

    | Dépôt | GitHub | Azure DevOps (Azure Repos) |
    |---|---|---|
    | Public | `repo:status` + `public_repo` | Code (Read) |
    | Privé | `repo` (contrôle total) | Code (Read) |

  - Le **PAT** sert à ACR pour lire le dépôt et **créer le webhook** (la notification envoyée à chaque commit). Bonne pratique : le stocker dans **Key Vault**, jamais dans un script ni dans un commit.
  - Format du contexte : `https://github.com/<user>/<repo>.git#<branche>:<dossier>` ou `https://dev.azure.com/<org>/<projet>/_git/<repo>#<branche>:<dossier>`.

### `git status` : « modified » ou « untracked » ?

- **Confusion :** `POINTS-A-REVOIR.md` apparaissait dans une autre section que `jour02-acr-tasks/` et `prompts/`.
- **À retenir :**
  - **Changes not staged / modified** : fichier **déjà suivi** par Git (présent dans un commit précédent), modifié depuis. C'est le cas de `POINTS-A-REVOIR.md`, commité au jour 1.
  - **Untracked** : fichier ou dossier **nouveau**, que Git n'a jamais enregistré.
  - Dans les deux cas, `git add` les ajoute au prochain commit. Équivalent Azure DevOps (Azure Repos) : identique, car c'est Git.
  - Les commandes `git` sont les mêmes dans PowerShell et dans bash.

### Warning `LF will be replaced by CRLF`

- **Confusion :** des warnings sont apparus pendant `git add`.
- **À retenir :**
  - **LF** = fin de ligne Linux, **CRLF** = fin de ligne Windows.
  - Le `.gitattributes` (`* text=auto`) stocke les fichiers en **LF sur GitHub** et les remet en **CRLF sur mon PC Windows**. Le warning annonce simplement cette conversion : **ce n'est pas une erreur**.
  - `Dockerfile` et les `*.sh` sont forcés en **LF partout** (`eol=lf`), parce que Linux, et donc le conteneur, ne lit pas bien le CRLF. C'est pour ça qu'ils n'apparaissent pas dans les warnings.
