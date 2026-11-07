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
