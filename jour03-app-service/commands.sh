#!/usr/bin/env bash
# =============================================================================
# Jour 3 : déployer un conteneur sur Azure App Service
#          (identité managée -> ACR, App Settings, référence Key Vault, journaux)
# Commandes tapées pendant les séances (8, 11, 12 et 15 novembre 2026), dans l'ordre.
# Terminal : Windows PowerShell, depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# Doc : https://learn.microsoft.com/fr-fr/azure/app-service/configure-custom-container?pivots=container-linux
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Quelle image déployer ? Tag UNIQUE (dd9) plutôt que "latest"
#    (latest = tag stable qui bouge, à réserver aux images de base)
# -----------------------------------------------------------------------------
az acr repository show-tags --name acrai200david --repository monapp --output table

# -----------------------------------------------------------------------------
# 1. Infrastructure : groupe de ressources + plan App Service Linux B1 + application web
#    plan (Microsoft.Web/serverFarms)  = les VM qu'on paie
#    application web (Microsoft.Web/sites) = la config de lancement du conteneur
#                                            (image, App Settings, port, URL)
# -----------------------------------------------------------------------------
az group create --name rg-ai200-jour03 --location francecentral
az appservice plan create --name plan-ai200-jour03 --resource-group rg-ai200-jour03 --is-linux --sku B1
#   --is-linux : conteneur Linux -> plan Linux (dans le JSON : "reserved": true)
az webapp create --resource-group rg-ai200-jour03 --plan plan-ai200-jour03 --name app-ai200-david --container-image-name acrai200david.azurecr.io/monapp:dd9
#   nom d'application web globalement unique -> https://app-ai200-david.azurewebsites.net

# -----------------------------------------------------------------------------
# 2. Téléchargement de l'image depuis l'ACR par IDENTITÉ MANAGÉE (pas d'utilisateur admin)
# -----------------------------------------------------------------------------
# 2.1 identité managée affectée par le système de l'application web
$principalId = az webapp identity assign --resource-group rg-ai200-jour03 --name app-ai200-david --query principalId --output tsv
# 2.2 ID de ressource de l'ACR (= l'étendue de l'attribution)
$registryId = az acr show --name acrai200david --query id --output tsv
# 2.3 attribution du rôle RBAC AcrPull à l'identité managée de l'application web, sur l'ACR
az role assignment create --assignee $principalId --scope $registryId --role "AcrPull"
# 2.4 dire à l'application web d'utiliser son identité managée pour s'authentifier auprès de l'ACR
az webapp config set --resource-group rg-ai200-jour03 --name app-ai200-david --generic-configurations '{\"acrUseManagedIdentityCreds\": true}'
#   PowerShell : les guillemets du JSON doivent être échappés (\")

# -----------------------------------------------------------------------------
# 3. App Settings = variables d'environnement du conteneur
#    (elles écrasent appsettings.json ; chaque modification REDÉMARRE l'application)
# -----------------------------------------------------------------------------
az webapp config appsettings set --resource-group rg-ai200-jour03 --name app-ai200-david --settings WEBSITES_PORT=8000 "APP_MESSAGE=Bonjour depuis App Service"
#   WEBSITES_PORT=8000 : mon API écoute sur 8000, App Service envoie sur 80 par défaut
az webapp config appsettings list --resource-group rg-ai200-jour03 --name app-ai200-david --output table
#   la sortie de "set" masque les valeurs (null) ; "list" les affiche
az webapp restart --resource-group rg-ai200-jour03 --name app-ai200-david   # si la page n'a pas changé (+ Ctrl+F5)

# -----------------------------------------------------------------------------
# 4. Secret dans Key Vault + référence Key Vault dans un App Setting
# -----------------------------------------------------------------------------
# 4.0 fournisseur de ressources non enregistré (erreur MissingSubscriptionRegistration)
az provider register --namespace Microsoft.KeyVault
az provider show --namespace Microsoft.KeyVault --query registrationState --output tsv   # Registering -> Registered

# 4.1 Key Vault en mode RBAC (nom globalement unique, 3 à 24 caractères)
#     suppression réversible 90 jours par défaut ; protection contre la purge NON activée (lab)
az keyvault create --name kv-ai200-david --resource-group rg-ai200-jour03 --location francecentral --enable-rbac-authorization true
$kvId = az keyvault show --name kv-ai200-david --query id --output tsv

# 4.2 MOI : rôle RBAC "Key Vault Secrets Officer" pour pouvoir créer le secret
$userId = az ad signed-in-user show --query id --output tsv
az role assignment create --assignee $userId --scope $kvId --role "Key Vault Secrets Officer"
#     secret factice ; --query pour ne PAS afficher la valeur dans la sortie
az keyvault secret set --vault-name kv-ai200-david --name DB-PASSWORD --value "Faux-MotDePasse-123" --query "{name:name, id:id}"
#     nom de secret : lettres, chiffres, tirets uniquement (DB-PASSWORD, pas DB_PASSWORD)

# 4.3 l'identité managée de l'application web : rôle RBAC "Key Vault Secrets User" (lecture)
$appPrincipalId = az webapp identity show --resource-group rg-ai200-jour03 --name app-ai200-david --query principalId --output tsv
az role assignment create --assignee $appPrincipalId --scope $kvId --role "Key Vault Secrets User"

# 4.4 App Setting DB_PASSWORD = référence Key Vault
#     PIÈGE PowerShell + az.cmd : les parenthèses sont mangées -> la ")" finale disparaît
#     -> la référence n'est pas résolue et l'app reçoit le texte brut "@Microsoft.KeyVault(..."
#     Solution : --% (arrêt de l'analyse PowerShell) + guillemets doubles
az --% webapp config appsettings set --resource-group rg-ai200-jour03 --name app-ai200-david --settings "DB_PASSWORD=@Microsoft.KeyVault(SecretUri=https://kv-ai200-david.vault.azure.net/secrets/DB-PASSWORD)"
#     Les 2 syntaxes (version facultative ; sans version = dernière version, rafraîchie sous 24 h) :
#       @Microsoft.KeyVault(SecretUri=https://<coffre>.vault.azure.net/secrets/<nom>/<version>)
#       @Microsoft.KeyVault(VaultName=<coffre>;SecretName=<nom>;SecretVersion=<version>)
#     Vérif : /secret -> "Fau***" ; portail > application web > Variables d'environnement
#             > colonne Source = "Coffre de clés" avec coche verte

# -----------------------------------------------------------------------------
# 5. Journaux du conteneur (sortie console ILogger de l'API .NET)
#    "docker" dans le nom = historique ; ça veut dire "journaux du conteneur"
# -----------------------------------------------------------------------------
az webapp log config --resource-group rg-ai200-jour03 --name app-ai200-david --docker-container-logging filesystem
az webapp log tail --resource-group rg-ai200-jour03 --name app-ai200-david   # Ctrl+C pour arrêter
#   requête visible : "Request starting HTTP/1.1 GET ..." ... "Request finished ... 200"

# -----------------------------------------------------------------------------
# 6. Nettoyage (il ne reste que l'ACR dans rg-ai200-socle)
# -----------------------------------------------------------------------------
# 6.1 / 6.2 attribution AcrPull : elle est sur l'ACR (rg-ai200-socle), donc PAS supprimée
#           avec rg-ai200-jour03 -> on la supprime AVANT, sinon elle reste orpheline
$principalId = az webapp identity show --resource-group rg-ai200-jour03 --name app-ai200-david --query principalId --output tsv
$registryId = az acr show --name acrai200david --query id --output tsv
az role assignment list --assignee $principalId --scope $registryId --output table     # toujours "list" avant "delete"
az role assignment delete --assignee $principalId --role AcrPull --scope $registryId
az role assignment list --assignee $principalId --scope $registryId --output table     # vide

# 6.3 groupe de ressources du jour (plan + application web + identité managée + Key Vault)
az group delete --name rg-ai200-jour03 --yes                 # définitif : pas de corbeille pour un RG

# 6.4 Key Vault : suppression réversible -> "corbeille" 90 jours, nom réservé -> purge
az keyvault list-deleted --resource-type vault --output table
az keyvault purge --name kv-ai200-david                       # définitif (possible car pas de purge protection)

# 6.5 vérification finale
az group list --output table       # rg-ai200-socle (+ azure-signup-rg, gratuit)
az resource list --output table    # acrai200david (+ azure-free-service, gratuit)
