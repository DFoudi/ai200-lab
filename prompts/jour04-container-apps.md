# Jour 4 : Azure Container Apps, configuration de l'environnement et gestion des révisions

Je prépare la certification Microsoft AI-200 (Développement de solutions cloud IA sur Azure).
Je viens du C# et j'apprends Python. Aujourd'hui, c'est le jour 4 de mon plan : Azure Container Apps, configuration de l'environnement et gestion des révisions.
Durée visée : 40 minutes environ.
Jours précédents : un ACR Basic dans rg-ai200-socle avec l'image monapp (jour 1), des ACR Tasks (jour 2), App Service avec App Settings et références Key Vault (jour 3).
Relis NOTES.md et les commands.sh des jours précédents pour retrouver le nom de mon registre, les tags disponibles et le port de l'app.

Ton rôle : tu es mon guide, pas mon exécutant.
- Ne lance AUCUNE commande Azure (az) à ma place. Donne-moi la commande, explique chaque paramètre, puis attends que je la tape et que je te colle le résultat.
- Pour toute explication ou commande Azure, vérifie d'abord dans la documentation Microsoft Learn (via le MCP microsoft-learn) et donne-moi le lien de la page utilisée.
- Si je bloque : indice d'abord, puis une comparaison avec ce que j'ai fait sur App Service au jour 3, puis la solution.
- Avance étape par étape : une étape, je valide, puis la suivante.
- N'utilise que des valeurs factices pour les secrets.

Déroulé de la séance :

0. Rappel en 5 lignes : où se situe Container Apps entre App Service et AKS ? Qu'est-ce qu'un environnement Container Apps, et que partagent les apps d'un même environnement ? Différence entre le plan Consommation et les profils de charge de travail.

1. Préparation : vérifie avec moi que l'extension containerapp est à jour et que les fournisseurs Microsoft.App et Microsoft.OperationalInsights sont enregistrés. Rappelle-moi quel tag de monapp utiliser (az acr repository show-tags).

2. Environnement : guide-moi pour créer le RG rg-ai200-jour04 (francecentral) et un environnement Container Apps. Explique ce qui est créé automatiquement avec lui (Log Analytics) et à quoi ça servira pour le dépannage du jour 7.

3. Première app :
   - crée la container app monapp depuis mon ACR, avec ingress externe sur le port de l'app
   - pull par identité managée système (--registry-identity system), pas d'utilisateur admin
   - variables d'environnement APP_MESSAGE et APP_VERSION=1
   - je teste l'URL publique (route /)
   Compare avec ce que j'ai dû configurer sur App Service au jour 3 (AcrPull, WEBSITES_PORT…).

4. Secrets :
   - ajoute un secret db-pass (valeur factice) au niveau de l'app
   - référence-le dans la variable DB_PASSWORD avec secretref:
   - je teste /secret
   - explique comment référencer plutôt un secret Key Vault depuis Container Apps (sans le mettre en place)

5. Révisions, le cœur de la séance :
   - liste les révisions après chaque modification de l'étape 3 et de l'étape 4 : laquelle a créé une nouvelle révision, laquelle non, et pourquoi ? (portée révision ou portée application)
   - explique pourquoi un secret modifié n'est pas pris en compte sans redémarrer la révision
   - passe en mode multiple révisions
   - crée une nouvelle révision avec --revision-suffix v2 et APP_VERSION=2
   - répartis le trafic à 80/20 entre l'ancienne et la nouvelle révision ; je rafraîchis / une vingtaine de fois et je compte les réponses
   - ajoute un label à la révision v2 et teste son URL dédiée
   - bascule 100 % du trafic sur v2, puis désactive l'ancienne révision
   Explique la différence entre mode single et mode multiple, et quand utiliser chacun (blue/green, canary).

6. Nettoyage : suppression du RG rg-ai200-jour04. Vérifie avec moi qu'il ne reste rien qui coûte, hors l'ACR du socle.

7. Notes : crée jour04-container-apps/commands.sh avec toutes les commandes tapées, commentées. Ajoute une section "Jour 4" dans NOTES.md avec les 5 points clés pour l'examen, dont un tableau des modifications « crée une révision / ne crée pas de révision ».

8. Quiz : pose-moi 3 questions de type examen AI-200, une par une, et attends ma réponse avant de corriger :
   - une sur ce qui déclenche une nouvelle révision
   - une sur la répartition du trafic pour un déploiement canary
   - une sur le choix entre App Service, Container Apps et AKS pour un scénario donné
