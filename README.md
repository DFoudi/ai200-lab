# ai200-lab — Labs pratiques Azure en C#/.NET

Préparation de la certification **Microsoft AI-200** (Développement de solutions cloud IA sur Azure), par la pratique.
Chaque jour = un lab complet sur Azure : une API **C# / ASP.NET Core (.NET 10)** conteneurisée, déployée, configurée, diagnostiquée, puis nettoyée.

Tout est fait en **Azure CLI**, en suivant les parcours **Microsoft Learn** du cursus AI-200.

---

## 🗂️ Les labs

| Jour | Thème | Ce qui est mis en pratique | Dossier |
|---|---|---|---|
| 1 | **Azure Container Registry** | Build d'images dans le cloud (`az acr build`), tags stables vs uniques, nettoyage d'images | [`jour01-acr`](jour01-acr) |
| 2 | **ACR Tasks** | Dockerfile multi-étapes avec **tests xUnit** (le push est bloqué si les tests échouent), task multi-étapes YAML, déclencheurs par commit et minuteur | [`jour02-acr-tasks`](jour02-acr-tasks) |
| 3 | **Azure App Service** | Conteneur Linux sur App Service, pull depuis ACR par **identité managée** (rôle AcrPull), App Settings, **références Key Vault**, journaux en direct | [`jour03-app-service`](jour03-app-service) |
| 4 | **Side-cars App Service** | Application à 2 conteneurs C# : API principale + faux modèle d'IA en side-car, communication via `localhost`, diagnostic d'une vraie panne de démarrage | [`jour04-sidecar`](jour04-sidecar) |
| 5 | **Azure Container Apps** | Environnement Consommation + Log Analytics, secrets (`secretref:`), **révisions**, déploiement **canary 80/20**, labels, bascule et désactivation | [`jour05-container-apps`](jour05-container-apps) |
| 6 | **Gérer et dépanner Container Apps** | Panne volontaire (mauvais port d'entrée), diagnostic par les **journaux système** (sonde de démarrage en échec, redémarrage en boucle), réparation, **sondes d'intégrité**, réglage CPU/RAM et réplicas min/max | [`jour06-gerer-container-apps`](jour06-gerer-container-apps) |

Chaque dossier contient un `commands.sh` : toutes les commandes du lab, dans l'ordre, commentées (y compris les erreurs rencontrées et leur correction).

📝 Les points clés de chaque jour (concepts, pièges, coûts) sont résumés dans [**NOTES.md**](NOTES.md).

---

## 🧰 Technologies

- **C# / ASP.NET Core (.NET 10)** — API avec controllers, `IHttpClientFactory`, `IConfiguration`
- **xUnit** + `WebApplicationFactory` — tests d'intégration exécutés pendant le build de l'image
- **Dockerfile multi-étapes** (build / test / runtime, utilisateur non-root)
- **Azure CLI** — Container Registry, ACR Tasks, App Service, Container Apps, Key Vault, RBAC
- **Microsoft Entra ID** — identités managées, attributions de rôles (AcrPull, Key Vault Secrets User/Officer)

---

## ✅ Bonnes pratiques appliquées

- **Aucun secret dans le code ni dans les images** : variables d'environnement, références Key Vault, secrets Container Apps — uniquement des valeurs factices dans ce dépôt.
- **Identité managée plutôt que mots de passe** pour le pull d'images (pas d'utilisateur admin ACR).
- **Tags d'image uniques** (ID de run ACR) pour les déploiements, tags stables réservés aux images de base.
- **Tests avant publication** : l'image n'est poussée que si les tests passent.
- **Maîtrise des coûts** : un groupe de ressources par lab, supprimé en fin de séance (attributions de rôles orphelines et Key Vault en suppression réversible compris).

---

## ▶️ Lancer une API en local

Prérequis : [.NET 10 SDK](https://dotnet.microsoft.com/download).

Seuls les jours 1, 2 et 4 contiennent du code C# : les jours 3 et 5 réutilisent l'image `monapp` du jour 2 et ne contiennent que des commandes Azure.

```bash
# Jour 1 : l'API, sur le port 8000 (le même que dans le conteneur)
cd jour01-acr/app
ASPNETCORE_HTTP_PORTS=8000 dotnet run          # PowerShell : $env:ASPNETCORE_HTTP_PORTS=8000; dotnet run
# puis : http://localhost:8000/health

# Jour 2 : les tests xUnit
dotnet test jour02-acr-tasks/tests/MonApp.Tests

# Jour 4 : l'API principale + le side-car, dans 2 terminaux
ASPNETCORE_HTTP_PORTS=5000 dotnet run --project jour04-sidecar/model-server   # le side-car
ASPNETCORE_HTTP_PORTS=8080 dotnet run --project jour04-sidecar/chat-api       # l'API principale
# puis : http://localhost:8080/chat?question=Bonjour
```

Pour rejouer un lab sur Azure : suivre le `commands.sh` du dossier (un compte Azure et Azure CLI sont nécessaires ; les ressources sont payantes tant qu'elles existent).

---

## 📚 Ressources

- [Guide d'étude AI-200](https://learn.microsoft.com/fr-fr/credentials/certifications/resources/study-guides/ai-200)
- [Parcours : Implémenter l'hébergement d'applications conteneur sur Azure](https://learn.microsoft.com/fr-fr/training/paths/implement-container-app-hosting-azure/)
- [Documentation Azure Container Apps](https://learn.microsoft.com/fr-fr/azure/container-apps/)

---

*Projet en cours — de nouveaux labs sont ajoutés au fil de la préparation (Container Apps avancé, AKS, Cosmos DB, PostgreSQL, Redis, Functions, Service Bus, observabilité…).*
