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
