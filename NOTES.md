# Notes : préparation AI-200

Ressources :
- [Guide d'étude AI-200](https://learn.microsoft.com/fr-fr/credentials/certifications/resources/study-guides/ai-200)
- [Évaluation d'entraînement](https://learn.microsoft.com/fr-fr/credentials/certifications/azure-ai-cloud-developer-associate/?practice-assessment-type=certification)
- Les notions qui m'ont posé problème : [POINTS-A-REVOIR.md](POINTS-A-REVOIR.md)

---

## Jour 1 : Azure Container Registry (ACR)

Réalisé : une API C# (controllers) avec les routes `/`, `/secret` et `/health`, un Dockerfile multi-stage .NET 10, le resource group `rg-ai200-socle`, l'ACR `acrai200david` (Basic), les images `monapp:v1`, `v2` et `latest` buildées dans le cloud, puis le nettoyage.
Commandes : [jour01-acr/commands.sh](jour01-acr/commands.sh)

### Les 5 points clés pour l'examen

1. **Les SKU** : Basic (10 Go, dev/test), Standard (100 Go), Premium (500 Go). **Seul Premium** offre la **géoréplication**, **Private Link / endpoints privés**, les **clés gérées par le client**, les zones de disponibilité et la **stratégie de rétention** des manifests sans tag. Dès qu'une question mentionne l'une de ces fonctions, la réponse est Premium.

2. **`az acr build`** (*quick task* d'ACR Tasks) = **build + push dans le cloud, sans Docker local**. Le contexte (le dossier) est envoyé, en tenant compte du `.dockerignore`, puis le Dockerfile est exécuté sur un agent Azure, et l'image est poussée dans le registre. ACR Tasks enregistre aussi l'image de base et peut **reconstruire automatiquement** quand elle est mise à jour (*base image update trigger*).

3. **Tag ≠ digest.** Le **digest** (`sha256:…`) identifie une image de façon unique et immuable. Le **tag** est une étiquette déplaçable, et plusieurs tags peuvent pointer sur le même digest (`v2` et `latest`). `latest` n'a rien d'automatique. Notation : `monapp:v2` (par tag), `monapp@sha256:…` (par digest).

4. **Untag ≠ delete.** `az acr repository untag` retire **seulement le tag** : l'image reste stockée (sans tag) et **facturée**. `az acr repository delete` supprime **le manifest et tous ses tags**. Piège : `delete --image monapp:v2` supprime aussi `latest` s'il partage le digest. Nettoyage automatique : `acr purge` (tous les SKU) ou la retention policy (Premium).

5. **Authentification et sécurité.** Le **compte admin** est **désactivé par défaut**, et Microsoft recommande **Entra ID** (`az acr login`) ou une **identité managée** (rôle `AcrPull`) pour Container Apps. Un **secret ne va jamais** dans le code ni dans le Dockerfile (`ENV` est lisible). Il est injecté au moment de l'exécution (secrets Container Apps / Key Vault). Sur un abonnement neuf, l'erreur `MissingSubscriptionRegistration` se corrige avec `az provider register --namespace Microsoft.ContainerRegistry`.

### Coûts

- **ACR Basic** : ~0,17 $/jour, soit **~5 $/mois**, facturé même sans utilisation. C'est la seule ressource payante. Elle est conservée exprès pour les jours suivants.
- Les builds ACR Tasks sont facturés à la seconde (quelques centimes).
- Le resource group et le budget sont gratuits.
- Budget `budget-ai200` : 15 €/mois, alertes à 50/80/100 %. ⚠️ Un budget **alerte mais ne coupe rien**.

---

## Jour 2 : ACR Tasks

Réalisé : des tests xUnit (`WebApplicationFactory`) sur `/health`, un Dockerfile en 3 stages (build / test / final), une task multi-étapes `acr-task.yaml` (build-tests → run-tests → build-image → push-image), une task enregistrée `monapp-ci` avec ses 3 déclencheurs (commit, timer, image de base), puis le nettoyage (task supprimée, PAT révoqué).
Commandes : [jour02-acr-tasks/commands.sh](jour02-acr-tasks/commands.sh)

### Les 5 points clés pour l'examen

1. **Les 3 façons d'utiliser ACR Tasks.**
   - `az acr build` = **quick task** : 1 Dockerfile, build et **push automatique**.
   - `az acr run --file x.yaml` = quick task **multi-étapes**, sans push automatique : il faut une étape `push`.
   - `az acr task create` = task **enregistrée** dans l'ACR, avec des **déclencheurs**.

   On la relance à la main avec `az acr task run`. Dans `list-runs`, une quick task n'a **pas de nom de task** et a TRIGGER = Manual.

2. **Le YAML multi-étapes** (`version: v1.1.0` pour les alias `$Registry`, `$ID`…). Il y a 3 types d'étapes : `build` (docker build), `cmd` (lancer un conteneur) et `push`. Les étapes s'exécutent **dans l'ordre**, et la task **s'arrête à la première étape en échec** (code de sortie ≠ 0). Si les tests échouent, l'image n'est jamais poussée (preuve : `dd5` absent). `$ID` = `{{.Run.ID}}`, qui sert à taguer chaque image de façon unique.

3. **Le déclencheur de code source** (commit). Il faut `--context https://github.com/<user>/<repo>.git#<branche>:<dossier>` et `--git-access-token <PAT>`. ACR crée un **webhook** sur le dépôt, et chaque push sur la branche lance la task (TRIGGER = Commit). Ça fonctionne avec **GitHub et Azure DevOps**. Droits du PAT GitHub : dépôt public = `repo:status` + `public_repo`, dépôt privé = `repo`. Azure DevOps = Code (Read).

4. **Le déclencheur minuteur.** `--schedule` à la création, ou `az acr task timer add --timer-name … --schedule "…"`. Expression **cron à 5 champs** (`minute heure jour mois jour-semaine`), **en UTC**, sans secondes ni année, fréquence maximale 1 fois par minute. Une task peut avoir **plusieurs** minuteurs. Exemple : `"0 12 * * Mon-Fri"` = midi UTC en semaine.

5. **Le déclencheur d'image de base**, activé **par défaut**. ACR enregistre les images de base du Dockerfile (`baseImageDependencies` : `dotnet/sdk`, `dotnet/aspnet` + digest). Quand l'image de base est mise à jour (correctif OS ou framework), ACR **reconstruit automatiquement** l'image : c'est le **patching automatique**.

### Nettoyage et sécurité

- `az acr task delete` supprime la task, ses déclencheurs **et le webhook**. Le **PAT doit être révoqué à la main** sur GitHub.
- Un secret affiché (capture, chat, log) est **compromis** : on le révoque et on le régénère. En production, on le range dans **Key Vault**.
- Ce qu'on a fait est du **CI** (build, test, publication de l'image), pas encore du **CD** (déploiement automatique sur App Service ou Container Apps).

### Coûts

- Les runs ACR Tasks sont facturés **à la seconde** : environ 1 min 20 par run, soit quelques centimes.
- Il reste **uniquement l'ACR Basic** (~5 $/mois). Les images `dd4` à `dd9` occupent quelques centaines de Mo, inclus dans les 10 Go.

---

## Jour 3 : déployer un conteneur sur Azure App Service

Réalisé :
- un plan App Service Linux B1 et l'application web `app-ai200-david`, qui exécute l'image `monapp:dd9` de l'ACR ;
- le téléchargement de l'image par **identité managée** (rôle RBAC AcrPull) ;
- des App Settings (`WEBSITES_PORT`, `APP_MESSAGE`) ;
- un secret Key Vault lu via une **référence Key Vault** ;
- les journaux du conteneur en direct ;
- le nettoyage (attribution AcrPull, groupe de ressources, purge du Key Vault).

Commandes : [jour03-app-service/commands.sh](jour03-app-service/commands.sh)
Module MS Learn : [Déployer des conteneurs sur Azure App Service](https://learn.microsoft.com/fr-fr/training/modules/deploy-containers-azure-app-service/)

### Les 5 points clés pour l'examen

1. **Plan ≠ application web.**
   - Le **plan App Service** (`Microsoft.Web/serverFarms`) contient les VM qu'on paie : OS, région, niveau tarifaire, nombre d'instances. Un conteneur Linux demande un plan **Linux** (`--is-linux`).
   - L'**application web** (`Microsoft.Web/sites`) est la configuration de lancement du conteneur : image, App Settings, port, URL `*.azurewebsites.net`.
   - Les applications web d'un même plan partagent ses VM.

2. **Télécharger l'image depuis l'ACR : l'identité managée est la bonne réponse.**
   - On active l'identité managée de l'application web (`az webapp identity assign`).
   - On lui attribue le rôle RBAC **AcrPull** sur l'ACR.
   - On active `acrUseManagedIdentityCreds: true`.
   - Il n'y a aucun mot de passe à stocker ni à faire tourner, contrairement à l'utilisateur admin de l'ACR (déconseillé) ou à un principal de service avec un secret.
   - L'image est téléchargée à chaque démarrage, redémarrage ou scale out.

3. **App Settings = variables d'environnement du conteneur.**
   - Elles **écrasent** `appsettings.json`. Ordre ASP.NET Core : `appsettings.json` → `appsettings.{Env}.json` → User Secrets → variables d'environnement → ligne de commande.
   - **Modifier un App Setting redémarre l'application.**
   - `WEBSITES_PORT` indique le port d'écoute du conteneur (80 par défaut).
   - App Settings (`configuration["X"]`) ≠ Connection Strings (`GetConnectionString("X")`).
   - Un **slot setting** reste attaché à son emplacement lors d'un swap.

4. **La référence Key Vault** : dans un App Setting, on met une référence au lieu du secret.
   - Les deux syntaxes :
     ```
     @Microsoft.KeyVault(SecretUri=https://<coffre>.vault.azure.net/secrets/<nom>/<version>)
     @Microsoft.KeyVault(VaultName=<coffre>;SecretName=<nom>;SecretVersion=<version>)
     ```
   - La version est facultative. Sans version, App Service prend la **dernière version**, rafraîchie sous **24 h** ; une modification de config la recharge tout de suite.
   - Conditions :
     - l'identité managée de l'application web a le rôle RBAC **Key Vault Secrets User** (lecture) ;
     - pour créer un secret, il faut **Key Vault Secrets Officer**.
   - **Symptôme d'échec** (rôle manquant, syntaxe fausse, secret supprimé) : l'application reçoit le **texte brut** `@Microsoft.KeyVault(...)`. Le portail l'affiche dans Variables d'environnement, colonne Source « Coffre de clés » : coche verte = résolue.

5. **Key Vault : suppression réversible et purge.**
   - Un Key Vault supprimé (même via `az group delete`) part dans une « corbeille » pendant **90 jours**. Il y est récupérable (`az keyvault recover`), et son nom reste **réservé**.
   - `az keyvault purge` le supprime définitivement, **sauf** si la **protection contre la purge** est activée : personne ne peut alors purger avant la fin de la rétention.
   - Un groupe de ressources n'a **pas** de corbeille.

### Pièges rencontrés

- PowerShell + `az` : les parenthèses d'une référence Key Vault sont mangées. Il faut utiliser `az --% ... "DB_PASSWORD=@Microsoft.KeyVault(...)"`.
- `MissingSubscriptionRegistration` : le fournisseur de ressources n'est pas enregistré. On lance `az provider register --namespace Microsoft.KeyVault`.
- Une attribution de rôle est stockée sur la ressource **cible** : l'attribution AcrPull était dans `rg-ai200-socle`. Il faut la supprimer avant le groupe de ressources du jour, sinon elle reste orpheline.
- Tag **unique** (`dd9`) pour déployer, tag **stable** (`latest`) pour les images de base.

### Coûts

- Le plan B1 était gratuit le premier mois, puis coûte environ 13 €/mois. Le Key Vault Standard est facturé à l'opération (quelques centimes).
- Après nettoyage, il reste **uniquement l'ACR Basic** (~5 $/mois).

---

## Jour 4 : side-car sur Azure App Service

Réalisé : une application web App Service **en mode side-car**, avec 2 conteneurs C# :
- `chat-api`, le conteneur **principal**, sur le port 8080 ;
- `model-server`, un faux modèle d'IA en **side-car**, sur le port 5000.

Les deux images sont téléchargées depuis l'ACR par identité managée. `GET /chat?question=…` appelle le side-car via `localhost:5000`. On a aussi diagnostiqué une vraie panne de side-car (image introuvable).
Code et commandes : [jour04-sidecar/](jour04-sidecar/) · [commands.sh](jour04-sidecar/commands.sh)
Module MS Learn : [Exécuter des applications d'IA avec side-car sur Azure App Service](https://learn.microsoft.com/fr-fr/training/modules/deploy-sidecar-azure-app-service/)

### Les 5 points clés pour l'examen

1. **Un side-car est un conteneur auxiliaire dans la même application web.**
   - Il y a **un seul** conteneur principal (`isMain: true`), le **seul** à recevoir le trafic externe, et jusqu'à **9 side-cars** (`isMain: false`).
   - Linux uniquement.
   - Usages typiques : petit modèle d'IA local (extension **Phi-3/Phi-4**, `POST localhost:11434/v1/chat/completions`), cache **Redis** local (`localhost:6379`), télémétrie (OpenTelemetry).

2. **Le cycle de vie est partagé.** Les conteneurs démarrent, s'arrêtent et se mettent à l'échelle **ensemble** : 3 instances = 3 API + 3 side-cars. Ils consomment le CPU et la RAM du **même** plan.
   - **Un side-car en échec arrête toute l'application web**, y compris le conteneur principal.
   - On choisit un **service séparé** quand le composant est partagé par plusieurs applications, a besoin d'un **GPU**, doit se mettre à l'échelle **indépendamment** ou doit rester disponible quand l'API redémarre.

3. **Réseau et fichiers.**
   - Tous les conteneurs partagent le même réseau : ils s'appellent par **`localhost:<port>`**, avec **un port unique par conteneur**.
   - Le trafic externe n'arrive que sur le principal, port **80 ou 8080**.
   - Le volume **`/home`** est monté dans tous les conteneurs par défaut. Des montages de volume permettent de partager des fichiers entre conteneurs.
   - Les **App Settings sont partagés** par tous les conteneurs. On peut les surcharger par conteneur (`environmentVariables`).

4. **La configuration est différente du conteneur classique.**
   - Création : `az webapp create … --sitecontainers-app` (`LinuxFxVersion=sitecontainers`), puis `az webapp sitecontainers create` par conteneur.
   - Conversion d'une application existante : `az webapp sitecontainers convert --mode sitecontainers`.
   - **`WEBSITES_PORT` et `DOCKER_REGISTRY_SERVER_*` ne s'appliquent plus.**
   - Le téléchargement d'image par identité managée se règle **par conteneur** : `--system-assigned-identity true` (`authType: SystemIdentity`) ou `--user-assigned-identity <clientId>`. Il faut toujours le rôle RBAC **AcrPull** sur l'ACR.

5. **Diagnostiquer.**
   - `az webapp log tail` montre les journaux de **tous** les conteneurs.
   - Les autres outils : `az webapp sitecontainers log` / `status`, et le portail (Diagnostiquer et résoudre les problèmes).
   - Les causes classiques :
     - **image introuvable** (`ImageNotFoundFailure`) : faute de frappe dans le nom ou le tag, non détectée à la création ;
     - **AcrPull manquant** ;
     - **deux conteneurs sur le même port** ;
     - **RAM insuffisante** pour le modèle.
   - `LastError` est la **dernière** erreur (historique). `Site started` indique que le site tourne.

### Pièges rencontrés

- **Nom du conteneur ≠ nom de l'image** : le premier est libre, le second doit exister exactement dans l'ACR.
- **`localhost` dépend de qui l'appelle** : depuis mon navigateur, c'est mon PC. Un side-car n'est jamais joignable depuis Internet.
- `az resource list` liste les **ressources** ; `az group list` liste les **groupes de ressources**.

### Coûts

- Plan B1 utilisé environ 45 min, soit quelques centimes. Supprimé le soir même, ainsi que l'attribution AcrPull.
- Les images `chat-api:v1` et `model-server:v1` restent dans l'ACR (incluses dans les 10 Go du Basic).

---

## Jour 5 : Azure Container Apps, environnement, secrets et révisions

Réalisé (parcours 2) :
- un environnement Container Apps (Consommation, avec Log Analytics créé automatiquement) ;
- la container app `monapp:dd9`, téléchargée depuis l'ACR par identité managée, avec une entrée externe sur le port 8000 ;
- des variables d'environnement et un secret (`secretref:`) ;
- puis un **déploiement canary** : mode multiple, révision `v2`, trafic 80/20, label `beta`, bascule à 100 % et désactivation de l'ancienne révision.

Commandes : [jour05-container-apps/commands.sh](jour05-container-apps/commands.sh)

### Les 5 points clés pour l'examen

1. **App Service / Container Apps / AKS.**
   - **App Service** : une application web (site, API).
   - **Container Apps** : des **microservices** en conteneurs, serverless, **mise à l'échelle jusqu'à 0** (KEDA), répartition du trafic entre révisions, Dapr intégré. Il tourne sur Kubernetes, **sans accès à l'API Kubernetes**.
   - **AKS** : quand on a besoin de l'**API Kubernetes** et du contrôle complet du cluster.
   - Un **environnement** est la frontière sécurisée des apps. Les apps d'un environnement partagent le **même réseau virtuel** et le **même Log Analytics**.
   - Plans : **Consommation** (payer à l'usage, 0 possible) ou **profils de charge de travail dédiés** (machines réservées, GPU possible, coût fixe).

2. **Une révision est un instantané immuable de la section `template`.**

   | Modification | Portée | Nouvelle révision ? |
   |---|---|---|
   | Image, variables d'environnement, CPU/RAM | révision (`properties.template`) | ✅ Oui |
   | Règles de mise à l'échelle, suffixe de révision (`--revision-suffix`) | révision (`properties.template`) | ✅ Oui |
   | **Secrets** | application (`properties.configuration`) | ❌ Non |
   | Entrée (ingress), **répartition du trafic**, **labels** | application | ❌ Non |
   | Mode de révision, identifiants de registre, Dapr | application | ❌ Non |

   - Un **secret modifié** n'est pas vu par les révisions en cours : elles ont lu la valeur **à leur démarrage**. Il faut **redémarrer** la révision (`az containerapp revision restart`) ou en déployer une nouvelle.

3. **Mode single ou multiple.**
   - **Single** (par défaut) : une seule révision active. La nouvelle remplace l'ancienne **sans interruption** : l'ancienne garde 100 % du trafic tant que la nouvelle n'est pas prête.
   - **Multiple** : plusieurs révisions actives, avec un **trafic réparti en %** (`az containerapp ingress traffic set --revision-weight a=80 b=20`, total = 100).
   - **Canary** : un petit % vers la nouvelle version, puis on augmente.
   - **Blue/green** : deux versions complètes, puis une bascule d'un coup.
   - Avant de créer une nouvelle révision en mode multiple, il faut **épingler** le trafic sur la révision actuelle. Sinon, la règle `latestRevision: true` lui donne 100 % immédiatement.
   - On met d'abord **0 % de trafic**, ensuite on **désactive** : une révision inactive ne coûte rien et reste réactivable.

4. **Labels et URL.**
   - URL principale : `https://<app>.<domaine-env>/`, avec la répartition du trafic.
   - URL de révision : `https://<app>--<suffixe>.<domaine-env>/`, qui change à chaque révision.
   - URL de **label** : `https://<app>---<label>.<domaine-env>/`, avec **3 tirets**.
   - Un label est **déplaçable** d'une révision à l'autre en gardant la même URL (idéal pour des testeurs).
   - Le label et la répartition du trafic sont **indépendants**.

5. **Identité managée et secrets.**
   - `az containerapp create --registry-identity system --registry-server <acr>` crée l'identité **et l'attribution AcrPull** automatiquement.
   - Mais cette commande crée d'abord une révision avec une **image publique**, puis une avec mon image : l'identité affectée par le système n'existe qu'**après** la création de l'app.
   - MS Learn recommande plutôt une identité **affectée par l'utilisateur** (créée avant, réutilisable).
   - Secret : `--secrets db-pass=<valeur>`, puis la variable `DB_PASSWORD=secretref:db-pass`.
   - Secret depuis **Key Vault** : `--secrets "db-pass=keyvaultref:<URI-du-secret>,identityref:<id-identité>"`, avec le rôle **Key Vault Secrets User**. Sans version dans l'URI, la nouvelle version est récupérée **sous 30 min** (App Service : 24 h).

### Pièges rencontrés

- `revision list` sans `--all` n'affiche que les révisions **actives**.
- Relancer `create` sur une app existante la met à jour, mais refait toute la procédure (2 révisions). Pour modifier, on utilise **`update`**.
- `az containerapp revision restart` : `--revision <nom>` est un **paramètre**, pas un mot de la commande.
- 20 appels en 80/20 ont donné 14/6 : la répartition est aléatoire par requête.

### Coûts

- Plan Consommation : quelques centimes, voire 0 € grâce à la franchise mensuelle. Groupe de ressources supprimé, attribution AcrPull supprimée.
- Il ne reste que l'ACR Basic.

---

## À faire en fin de parcours (révision examen)

- [ ] **Lab bonus, environ 20 min : déclencheur de mise à jour d'image de base (ACR Tasks).** Créer sa propre image de base dans l'ACR, la modifier, et vérifier que la tâche se relance toute seule (`az acr task list-runs` → TRIGGER = Image Update). Tutoriel : [Automatiser les builds d'images conteneur quand une image de base est mise à jour](https://learn.microsoft.com/fr-fr/azure/container-registry/container-registry-tutorial-base-image-update)
