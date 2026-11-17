#!/usr/bin/env bash
# =============================================================================
# Jour 4 : side-car sur Azure App Service (parcours 1, module 3)
#          chat-api (conteneur principal, port 8080) + model-server (side-car, port 5000)
# Commandes tapées pendant la séance du 17 novembre 2026, dans l'ordre.
# Terminal : Windows PowerShell, depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# Doc : https://learn.microsoft.com/fr-fr/azure/app-service/configure-sidecar
#       https://learn.microsoft.com/fr-fr/cli/azure/webapp/sitecontainers
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Test en local (sans Azure) : les 2 API C# dans 2 terminaux
#    (le port 8080 est déjà pris sur mon PC par IIS -> chat-api testée sur 8090)
# -----------------------------------------------------------------------------
#   $env:ASPNETCORE_HTTP_PORTS=5000; dotnet run --project jour04-sidecar/model-server
#   $env:ASPNETCORE_HTTP_PORTS=8090; dotnet run --project jour04-sidecar/chat-api
#   navigateur : http://localhost:8090/chat?question=Bonjour

# -----------------------------------------------------------------------------
# 1. Construire les 2 images dans l'ACR (ACR Tasks)
# -----------------------------------------------------------------------------
az acr build --registry acrai200david --image chat-api:v1 ./jour04-sidecar/chat-api          # run dda
az acr build --registry acrai200david --image model-server:v1 ./jour04-sidecar/model-server  # run ddb
#   dd9 -> dda -> ddb : compteur de runs de l'ACR (après 9 viennent les lettres)

# -----------------------------------------------------------------------------
# 2. Groupe de ressources + plan Linux B1 + application web EN MODE SIDE-CAR
# -----------------------------------------------------------------------------
az group create --name rg-ai200-sidecar --location francecentral
az appservice plan create --name plan-ai200-sidecar --resource-group rg-ai200-sidecar --is-linux --sku B1
az webapp create --name app-ai200-sidecar --resource-group rg-ai200-sidecar --plan plan-ai200-sidecar --sitecontainers-app
#   --sitecontainers-app : LinuxFxVersion=sitecontainers ; pas d'image ici, les conteneurs sont ajoutés à l'étape 4

# -----------------------------------------------------------------------------
# 3. Identité managée de l'application web + rôle RBAC AcrPull sur l'ACR
#    (une seule attribution pour les 2 conteneurs : même application web = même identité)
# -----------------------------------------------------------------------------
$principalId = az webapp identity assign --resource-group rg-ai200-sidecar --name app-ai200-sidecar --query principalId --output tsv
$registryId = az acr show --name acrai200david --query id --output tsv
az role assignment create --assignee $principalId --scope $registryId --role "AcrPull"
#   PAS de "acrUseManagedIdentityCreds" : en mode side-car, l'identité se choisit PAR CONTENEUR

# -----------------------------------------------------------------------------
# 4. Ajouter le conteneur principal et le side-car
# -----------------------------------------------------------------------------
az webapp sitecontainers create --name app-ai200-sidecar --resource-group rg-ai200-sidecar --container-name chat-api --image acrai200david.azurecr.io/chat-api:v1 --target-port 8080 --is-main true --system-assigned-identity true
az webapp sitecontainers create --name app-ai200-sidecar --resource-group rg-ai200-sidecar --container-name model-server --image acrai200david.azurecr.io/model-server:v1 --target-port 5000 --is-main false --system-assigned-identity true
#   Règles vérifiées par Azure à la création :
#     - un SEUL --is-main true   -> sinon "SiteContainer 'chat-api' with isMain=true already exists"
#     - un port PAR conteneur    -> sinon "targetPort must be unique"
#   Règle NON vérifiée à la création : l'existence de l'image dans l'ACR (voir 6.)

az webapp sitecontainers list --name app-ai200-sidecar --resource-group rg-ai200-sidecar --query "[].{nom:name, image:image, principal:isMain, port:targetPort}" --output table

# -----------------------------------------------------------------------------
# 5. Test + journaux de TOUS les conteneurs
# -----------------------------------------------------------------------------
az webapp log config --resource-group rg-ai200-sidecar --name app-ai200-sidecar --docker-container-logging filesystem
az webapp log tail --resource-group rg-ai200-sidecar --name app-ai200-sidecar      # Ctrl+C pour arrêter
#   navigateur : https://app-ai200-sidecar.azurewebsites.net/chat?question=Bonjour
#   -> {"question":"Bonjour","model":"fake-slm-v1","reply":"[modèle factice] ...","servedBy":"chat-api -> model-server (side-car)"}
#   un 404 sur "/" est normal : chat-api n'a que /chat et /health

# -----------------------------------------------------------------------------
# 6. Panne réelle (faute de frappe) et diagnostic
# -----------------------------------------------------------------------------
# Erreur commise : side-car créé avec --image .../modele-server:v1 (image inexistante)
#   -> commande ACCEPTÉE, panne seulement au démarrage. Dans log tail :
#      LastError: ImageNotFoundFailure ... Failed to pull image ... check for any misspellings
#      Site container: app-ai200-sidecar_chat-api terminated during site startup.
#      Site: app-ai200-sidecar stopped.          <- TOUTE l'application web s'arrête
az webapp sitecontainers status --name app-ai200-sidecar --resource-group rg-ai200-sidecar --container-name model-server
#   (a renvoyé "Expecting value: line 1 column 1" tant que le site ne démarrait pas -> passer par log tail)
# Correction possible en 1 commande (nom du conteneur libre, seul le nom de l'IMAGE compte) :
#   az webapp sitecontainers update --name app-ai200-sidecar --resource-group rg-ai200-sidecar --container-name modele-server --image acrai200david.azurecr.io/model-server:v1
# Correction choisie (renommer aussi le conteneur) : supprimer puis recréer
az webapp sitecontainers delete --name app-ai200-sidecar --resource-group rg-ai200-sidecar --container-name modele-server
#   puis la commande "create" de model-server de l'étape 4

# -----------------------------------------------------------------------------
# 7. Nettoyage (il ne reste que l'ACR et ses images)
# -----------------------------------------------------------------------------
$principalId = az webapp identity show --resource-group rg-ai200-sidecar --name app-ai200-sidecar --query principalId --output tsv
$registryId = az acr show --name acrai200david --query id --output tsv
az role assignment delete --assignee $principalId --role AcrPull --scope $registryId     # AVANT le RG : l'attribution est sur l'ACR
az role assignment list --assignee $principalId --scope $registryId --output table      # vide
az group delete --name rg-ai200-sidecar --yes
az group list --output table       # les groupes de ressources (les "dossiers")
az resource list --output table    # les ressources (le contenu) : acrai200david + azure-free-service
