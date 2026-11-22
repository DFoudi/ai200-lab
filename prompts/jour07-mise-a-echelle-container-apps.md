# Jour 7 : mettre à l'échelle des conteneurs dans Azure Container Apps (HTTP, KEDA)

> Parcours MS Learn 2 : **Déployer et gérer des applications sur Azure Container Apps**
> Module 3 : **Mettre à l'échelle des conteneurs dans Azure Container Apps**
> https://learn.microsoft.com/fr-fr/training/modules/scale-containers-azure-container-apps/

Objectif : observer une container app passer de 0 à plusieurs réplicas puis revenir à 0, avec deux déclencheurs :
1. une règle de mise à l'échelle **HTTP** (requêtes simultanées), déclenchée par un test de charge écrit en C# ;
2. une règle **KEDA** sur une **file d'attente Azure Storage** (nombre de messages), sans aucune requête HTTP.

Code : l'API C# `monapp` (image `acrai200david.azurecr.io/monapp:dd9`, port 8000) + un mini-programme C# de test de charge.

Règles de la séance :
- Je tape toutes les commandes `az` et `git push` ; le guide explique chaque paramètre et vérifie sur Microsoft Learn (lien fourni).
- Théorie de chaque unité expliquée en clair et en petits morceaux avant la pratique.
- Valeurs factices uniquement pour les secrets ; pas de chaîne de connexion affichée dans la conversation.
- 5 commits répartis au fil de la séance.

Déroulé :

0. Théorie en clair :
   - Configurer des règles de mise à l'échelle (HTTP, TCP, CPU, mémoire ; min/max réplicas ; intervalle d'interrogation 30 s ; refroidissement 300 s)
   - Implémenter une mise à l'échelle pilotée par les événements avec KEDA
   - Appliquer des scalers KEDA pour les charges de travail personnalisées
   - Sélectionner des ressources de calcul pour les performances et les coûts
   - Choisir et appliquer des modes de révision (révision unique recommandée avec les règles non HTTP)

1. Environnement `env-ai200-jour07` dans `rg-ai200-jour07` (francecentral) et container app `monapp` :
   `--min-replicas 0 --max-replicas 5 --scale-rule-name http-rule --scale-rule-type http --scale-rule-http-concurrency 1`.

2. Test de charge HTTP : programme C# (`HttpClient`, requêtes en parallèle), observation des réplicas (`az containerapp replica list`) pendant et après la charge.

3. KEDA : compte de stockage + file `jobs`, secret de l'app = chaîne de connexion (jamais affichée), règle `azure-queue` (`queueName=jobs`, `queueLength=5`, `--scale-rule-auth`), dépôt de 20 messages, observation de la montée en réplicas, vidage de la file et retour à 0 après le refroidissement.

4. Nettoyage : attribution AcrPull sur l'ACR, `az group delete --no-wait`, vérification.

5. Notes : `jour07-mise-a-echelle-container-apps/commands.sh`, section « Jour 7 » de NOTES.md, ligne du jour dans le README.

6. Quiz : 3 questions (règle par défaut et mise à l'échelle à zéro, KEDA, CPU/mémoire), une par une.
