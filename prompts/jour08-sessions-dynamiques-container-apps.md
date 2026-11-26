# Jour 8 : sessions dynamiques dans Azure Container Apps

> Parcours MS Learn 2 : **Déployer et gérer des applications sur Azure Container Apps**
> Module 4 : **Exécuter du code généré par l'IA en toute sécurité dans Azure Container Apps sessions dynamiques**
> https://learn.microsoft.com/fr-fr/training/modules/dynamic-sessions-azure-container-apps/
> Unités : 1. Introduction · 2. Choisir un pool de sessions dynamiques · 3. Configurer un pool de sessions sécurisées ·
> 4. Exécuter du code et échanger des fichiers · 5. Gérer les échecs de cycle de vie et d'exécution ·
> 6. Exercice · 7. Évaluation du module · 8. Résumé
> Docs : [Sessions dynamiques](https://learn.microsoft.com/fr-fr/azure/container-apps/sessions) ·
> [Pools de sessions](https://learn.microsoft.com/fr-fr/azure/container-apps/session-pool) ·
> [Référence CLI sessionpool](https://learn.microsoft.com/en-us/cli/azure/containerapp/sessionpool)

Objectif : exécuter du code dans des **bacs à sable isolés** (sessions Hyper-V) attribués à la demande depuis un **pool de sessions**, cas typique d'un agent d'IA qui exécute du code généré par un LLM sans risque pour l'application principale. Les **deux types de pool** du module sont pratiqués :
- **conteneur personnalisé** (`CustomContainer`) avec notre API C# `session-api` ;
- **interpréteur de code** (`PythonLTS`), comme l'exercice MS Learn (unité 6), appelé depuis un client **C#** au lieu de Flask.

Règles de la séance :
- Je tape toutes les commandes `az` et `git push` ; le guide explique chaque paramètre et vérifie sur Microsoft Learn (lien fourni).
- Théorie de chaque unité en clair et en petits morceaux avant la pratique.
- Aucun secret affiché ; jeton Entra rangé dans une variable, jamais collé.
- ~5 commits par séance complète, messages sans accents.

## Déjà fait

- [x] Plan et titre du module (commits du 23 et 25/11)
- [x] `session-api` : API C# (notes en mémoire par session, port 8080), testée en local
- [x] Image `acrai200david.azurecr.io/session-api:ddc` construite dans l'ACR
- [x] `rg-ai200-jour08` + environnement `env-ai200-jour08` (francecentral)

## Partie A : pool de conteneurs personnalisés (≈ 40 min)

| # | Étape | Durée |
|---|---|---|
| A0 | Vérifier l'environnement `env-ai200-jour08` (`Succeeded`) | 2 min |
| A1 | Théorie unités 1 à 3 en clair : isolation Hyper-V, `identifier`, deux types de pool, capacité (`--max-sessions`, `--ready-sessions`), cycle de vie (`--cooldown-period`), sortie réseau (`EgressDisabled`), rôle Session Executor | 8 min |
| A2 | **Identité managée affectée par l'utilisateur** `id-ai200-jour08` + attribution du rôle **AcrPull** sur l'ACR (avant la création du pool : le pool doit pouvoir tirer l'image dès sa création) | 7 min |
| A3 | `az containerapp sessionpool create` : `CustomContainer`, image `session-api:ddc`, `--target-port 8080`, `--registry-identity <id>`, `--cpu 0.25 --memory 0.5Gi`, `--max-sessions 5`, `--ready-sessions 1`, `--cooldown-period 300`, `--network-status EgressDisabled` | 8 min |
| A4 | `poolManagementEndpoint` + attribution du rôle **Azure ContainerApps Session Executor** à mon compte utilisateur sur le pool | 7 min |
| A5 | `commands.sh`, commit et push | 5 min |
| | Décision fin de séance : garder le pool (1 session prête = petit coût continu) ou le supprimer | 3 min |

## Partie B : client C# et isolation des sessions (≈ 45 min)

| # | Étape | Durée |
|---|---|---|
| B1 | Théorie unités 4 et 5 : exécuter du code, échanger des fichiers, expiration, délais, échecs | 8 min |
| B2 | `session-client` (console C#) : jeton Entra avec `Azure.Identity` (`AzureCliCredential`, portée `https://dynamicsessions.io/.default`), appels `POST /notes` et `GET /notes` avec `identifier=alice` puis `identifier=bob` | 12 min |
| B3 | Test : Alice ne voit pas les notes de Bob ; `.management/listSessions` ; `.management/stopSession` ; nouvelle session = notes perdues | 12 min |
| B4 | Test d'accès refusé : appel sans jeton → 401 (pourquoi le rôle Session Executor est indispensable) | 5 min |
| B5 | `commands.sh`, commit et push | 5 min |

## Partie C : interpréteur de code Python, comme l'exercice MS Learn (≈ 45 min)

| # | Étape | Durée |
|---|---|---|
| C1 | `az containerapp sessionpool create --container-type PythonLTS` (pas d'image, pas d'environnement) + rôle Session Executor | 8 min |
| C2 | `code-interpreter-client` (console C#) : envoyer du code Python « généré par une IA » et lire le résultat | 12 min |
| C3 | Téléverser un fichier de données, exécuter du code qui le lit, lister et télécharger les fichiers de la session | 10 min |
| C4 | Échec volontaire (code en erreur, boucle trop longue) : lire l'erreur, supprimer la session explicitement | 8 min |
| C5 | `commands.sh`, commit et push | 5 min |

## Partie D : nettoyage, notes et quiz (≈ 25 min)

| # | Étape | Durée |
|---|---|---|
| D1 | Nettoyage : attribution AcrPull sur l'ACR d'abord, puis `az group delete --no-wait`, vérification | 5 min |
| D2 | Section « Jour 8 » de NOTES.md (5 points clés, pièges, coûts) + ligne du jour dans le README | 8 min |
| D3 | Quiz : 3 questions (type de pool, rôle et jeton, isolation et `identifier`) + évaluation du module (unité 7) | 10 min |
| D4 | Commit et push final | 2 min |

**Total restant ≈ 2 h 35, soit 4 séances de 40 min.**
