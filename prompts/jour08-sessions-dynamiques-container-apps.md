# Jour 8 : sessions dynamiques dans Azure Container Apps

> Parcours MS Learn 2 : **Déployer et gérer des applications sur Azure Container Apps**
> Module 4 : **Exécuter du code généré par l'IA en toute sécurité dans Azure Container Apps sessions dynamiques**
> https://learn.microsoft.com/fr-fr/training/modules/dynamic-sessions-azure-container-apps/
> Unités : 1. Introduction · 2. Choisir un pool de sessions dynamiques · 3. Configurer un pool de sessions sécurisées ·
> 4. Exécuter du code et échanger des fichiers · 5. Gérer les échecs de cycle de vie et d'exécution ·
> 6. Exercice · 7. Évaluation du module · 8. Résumé
> Docs : [Sessions dynamiques](https://learn.microsoft.com/fr-fr/azure/container-apps/sessions) ·
> [Pools de sessions](https://learn.microsoft.com/fr-fr/azure/container-apps/session-pool) ·
> [Sessions de conteneur personnalisé](https://learn.microsoft.com/fr-fr/azure/container-apps/sessions-custom-container)

Objectif : exécuter du code dans des **bacs à sable isolés** (sessions Hyper-V) créés à la demande depuis un **pool de sessions** préchauffé, cas typique d'un agent d'IA qui exécute du code généré par un LLM sans risque pour l'application principale.

Code (C#) :
- `session-api` : petite API C# empaquetée en image (ACR Tasks), lancée dans chaque session ; elle garde des données **en mémoire** pour montrer qu'une session = un environnement isolé par `identifier` ;
- `session-client` : programme console C# qui obtient un jeton Microsoft Entra (`Azure.Identity`, audience `https://dynamicsessions.io`) et appelle le point de terminaison de gestion du pool avec deux identifiants différents.

Règles de la séance :
- Je tape toutes les commandes `az` et `git push` ; le guide explique chaque paramètre et vérifie sur Microsoft Learn (lien fourni).
- Théorie de chaque unité en clair et en petits morceaux avant la pratique.
- Aucun secret affiché ; jeton Entra rangé dans une variable, jamais collé.
- 5 commits répartis au fil de la séance, messages sans accents.

Déroulé :

0. Théorie en clair :
   - session dynamique = bac à sable isolé (Hyper-V), créé à la demande, identifié par `identifier` (4 à 128 caractères, non devinable) ;
   - pool de sessions : sessions préchauffées (`--ready-sessions`), plafond (`--max-sessions`), suppression après inactivité (`--cooldown-period`) ;
   - deux types : **interpréteur de code** (`PythonLTS`, `NodeLTS`, `Shell`, sans image) ou **conteneur personnalisé** (`CustomContainer`, son image, environnement avec profils de charge de travail) ;
   - sécurité : `--network-status EgressDisabled` par défaut, jeton Entra obligatoire, rôle **Azure ContainerApps Session Executor** sur le pool.

1. Code C# : `session-api` (+ Dockerfile) et `session-client` ; build de l'image dans l'ACR (`az acr build`, tag unique).

2. Infra : `rg-ai200-jour08`, environnement `env-ai200-jour08` (francecentral, quota 1 par région), pool `pool-ai200-jour08` de type `CustomContainer` (image de l'ACR, port cible, `--ready-sessions`, `--max-sessions`, `--cooldown-period`).

3. Accès : attribution du rôle RBAC **Azure ContainerApps Session Executor** à mon compte utilisateur sur le pool ; récupération de `poolManagementEndpoint`.

4. Test : `session-client` appelle l'API avec `identifier=alice` puis `identifier=bob` → données séparées ; liste des sessions (`.management/listSessions`) ; arrêt d'une session (`.management/stopSession`).

5. Nettoyage : attributions de rôle, `az group delete --no-wait`, vérification.

6. Notes : `jour08-sessions-dynamiques-container-apps/commands.sh`, section « Jour 8 » de NOTES.md, ligne du jour dans le README.

7. Quiz : 3 questions (interpréteur de code ou conteneur personnalisé, rôle et jeton, isolation et `identifier`), une par une.
