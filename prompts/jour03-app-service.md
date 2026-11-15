# Jour 3 : déployer un conteneur sur Azure App Service (variables d'environnement et secrets)

> Parcours MS Learn : **Implémenter l'hébergement d'applications conteneur sur Azure**
> Module 2 : **Déployer des conteneurs sur Azure App Service**
> https://learn.microsoft.com/fr-fr/training/modules/deploy-containers-azure-app-service/

Je prépare la certification Microsoft AI-200 (Développement de solutions cloud IA sur Azure).
Je suis développeur **C# / .NET**. Tout le code est en **C# (.NET 10, ASP.NET Core avec controllers)**. Si un extrait en Python apparaît dans ce prompt ou ailleurs, **traduis-le en C#**. Tu peux montrer l'équivalent Python d'un appel SDK **en lecture seule**, car les extraits de l'examen peuvent être en Python.
Aujourd'hui, c'est le jour 3 de mon plan : déployer un conteneur sur Azure App Service, avec des variables d'environnement et des secrets.
Durée visée : environ 40 minutes.
Jours précédents : un ACR Basic `acrai200david` dans `rg-ai200-socle` (jour 1), et des ACR Tasks (jour 2).
Relis NOTES.md et les commands.sh des jours 1 et 2 pour retrouver le nom de mon registre et les images disponibles.

Ton rôle : tu es mon guide, pas mon exécutant.
- Ne lance AUCUNE commande Azure (az) ni aucun git push à ma place. Donne-moi la commande, explique chaque paramètre, puis attends que je la tape et que je te colle le résultat.
- **Tu écris toi-même le code C#** si besoin, et tu me l'expliques. Moi, je me concentre sur Azure et je tape les commandes az.
- Pour toute explication ou commande Azure, vérifie d'abord dans la documentation Microsoft Learn et donne-moi le lien de la page utilisée.
- Si je bloque : d'abord un indice, puis une analogie avec ce que je connais en C#/.NET (appsettings.json, IConfiguration, User Secrets) ou en **Azure DevOps** (pas GitHub Actions), puis la solution.
- Avance étape par étape : une étape, je valide, puis la suivante.
- Ne me fais jamais afficher ni coller de vraie valeur secrète dans la conversation. Pour l'exercice, utilise une valeur factice.
- Réponses courtes, en français clair. Note dans POINTS-A-REVOIR.md (fichier personnel, jamais commité) tout ce qui me pose problème.

Déroulé de la séance :

0. Vérification : dis-moi quelle image et quel tag de `monapp` utiliser (vérifie avec moi via `az acr repository show-tags`). Rappelle en 3 lignes ce que fait chaque route de l'API C# (`InfoController` : `/`, `/secret`, `/health`), et sur quel port elle écoute (`ASPNETCORE_HTTP_PORTS=8000`).

1. Infrastructure : guide-moi pour créer le RG `rg-ai200-jour03` (francecentral), un plan App Service Linux en SKU B1 et une Web App configurée pour tourner sur mon image ACR.
   Explique pourquoi on choisit un plan Linux pour un conteneur, et ce que coûte un B1.

2. Pull depuis ACR par identité managée, sans utilisateur admin :
   - activer l'identité managée système de la Web App ;
   - donner le rôle AcrPull sur le registre à cette identité ;
   - activer `acrUseManagedIdentityCreds` dans la configuration de la Web App.
   Explique les alternatives (utilisateur admin, principal de service) et pourquoi l'identité managée est la bonne réponse à l'examen.

3. Variables d'environnement :
   - ajoute les App Settings `APP_MESSAGE` et `WEBSITES_PORT` (port de mon app : 8000) ;
   - je vérifie la route `/` dans le navigateur ;
   - explique ce qui se passe quand on modifie un App Setting (redémarrage), la différence entre App Settings et Connection Strings, et ce qu'est un « slot setting » (paramètre lié à un slot de déploiement). Juste l'explication, sans créer de slot.
   - analogie C# : les App Settings arrivent comme **variables d'environnement**, lues par `Environment.GetEnvironmentVariable` (mon code) ou par `IConfiguration`, et elles **écrasent** `appsettings.json`.

4. Secret via Key Vault :
   - crée un Key Vault en mode RBAC dans `rg-ai200-jour03` (explique la contrainte de nom globalement unique) ;
   - donne-moi le rôle Key Vault Secrets Officer pour que je puisse créer le secret, puis crée le secret `DB-PASSWORD` avec une valeur factice ;
   - donne le rôle Key Vault Secrets User à l'identité de la Web App ;
   - ajoute l'App Setting `DB_PASSWORD` avec une référence Key Vault. Montre-moi les deux syntaxes possibles (SecretUri et VaultName/SecretName), avec et sans version ;
   - je vérifie la route `/secret`, puis le statut de la référence (portail ou CLI).
   Explique ce qu'il se passe si l'identité n'a pas le rôle : quel symptôme je verrais dans l'app ?
   Analogie C# : User Secrets en local ↔ Key Vault en production.

5. Journaux : guide-moi pour activer les journaux du conteneur et les suivre en direct avec `az webapp log tail`. Je provoque une requête et je la retrouve dans les logs.

6. Nettoyage : suppression du RG `rg-ai200-jour03`.
   Explique ce qu'il advient du Key Vault supprimé (suppression réversible, nom réservé pendant la rétention), et comment le lister ou le purger si je veux réutiliser le même nom.
   Vérifie avec moi qu'il ne reste rien de payant, hors l'ACR du socle.

7. Notes : crée `jour03-app-service/commands.sh` avec toutes les commandes tapées, commentées. Ajoute une section « Jour 3 » dans NOTES.md avec les 5 points clés pour l'examen (dont la syntaxe exacte d'une référence Key Vault). Complète la section « Niveaux, SKU et plans » de POINTS-A-REVOIR.md (App Service, Key Vault).

8. Quiz : pose-moi 3 questions de type examen AI-200, **une par une, avec une seule exigence claire par question**, et attends ma réponse avant de corriger :
   - une sur le choix de la méthode d'authentification d'App Service vers ACR ;
   - une sur une référence Key Vault qui ne se résout pas ;
   - une sur App Settings et variables d'environnement.
