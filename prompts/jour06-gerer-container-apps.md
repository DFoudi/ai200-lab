# Jour 6 : gérer des conteneurs dans Azure Container Apps (diagnostic, journaux, sondes, ressources)

> Parcours MS Learn 2 : **Déployer et gérer des applications sur Azure Container Apps**
> Module 2 : **Gérer des conteneurs dans Azure Container Apps**
> https://learn.microsoft.com/fr-fr/training/modules/manage-containers-azure-container-apps/

Objectif : déployer volontairement une app en panne, la diagnostiquer (état des révisions, journaux, Log Analytics), la réparer, puis la rendre plus robuste avec des sondes d'intégrité et des ressources ajustées.
Code : l'API C# `monapp` (image `acrai200david.azurecr.io/monapp:dd9`, port 8000, route `/health`).
Le module 1 (environnement, variables, secrets, registre) et les révisions (canary, labels) ont été pratiqués au jour 5.

Règles de la séance :
- Je tape toutes les commandes `az` et `git push` ; le guide explique chaque paramètre et vérifie sur Microsoft Learn (lien fourni).
- Théorie de chaque unité expliquée en clair et en petits morceaux avant la pratique.
- Valeurs factices uniquement pour les secrets.
- 5 commits répartis au fil de la séance.

Déroulé :

0. Théorie en clair, une unité à la fois :
   - Mettre à jour des images et gérer les révisions en toute sécurité
   - Gérer le cycle de vie de l'application conteneur
   - Surveiller les journaux et résoudre les problèmes
   - Configurer des sondes de vérification de l'état et dépanner les défaillances
   - Optimiser les ressources de conteneur et la mise à l'échelle

1. Environnement `env-ai200-jour06` dans `rg-ai200-jour06` (francecentral) et container app `monapp` (image `dd9`, identité managée système, entrée externe sur le port 8000).

2. Panne volontaire : modifier le port cible de l'entrée (8000 → 80). L'app ne répond plus.

3. Diagnostic :
   - état d'approvisionnement et d'exécution des révisions (`az containerapp revision list`) ;
   - journaux console et système (`az containerapp logs show --type console|system`) ;
   - requête KQL dans l'espace de travail Log Analytics (`ContainerAppConsoleLogs_CL`, `ContainerAppSystemLogs_CL`).

4. Réparation (port 8000), puis retour arrière vers une révision saine (activer une ancienne révision et lui donner le trafic).

5. Robustesse :
   - sondes d'intégrité liveness et readiness sur `/health` (port 8000), observation d'une sonde en échec ;
   - ajustement CPU/RAM (`--cpu`, `--memory`) et réplicas (`--min-replicas`, `--max-replicas`).

6. Nettoyage : attribution AcrPull sur l'ACR, puis `az group delete --no-wait`, vérification qu'il ne reste que l'ACR.

7. Notes : `jour06-gerer-container-apps/commands.sh`, section « Jour 6 » de NOTES.md, ligne du jour dans le README.

8. Quiz : 3 questions (une sur les outils de diagnostic, une sur les sondes, une sur CPU/RAM et réplicas), une par une.
