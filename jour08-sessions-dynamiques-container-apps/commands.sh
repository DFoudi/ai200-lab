#!/usr/bin/env bash
# =============================================================================
# Jour 8 : exécuter du code généré par l'IA en toute sécurité dans les sessions dynamiques
#          d'Azure Container Apps (parcours 2, module 4)
# Commandes tapées pendant les séances (à partir du 25 novembre 2026), dans l'ordre.
# Terminal : Windows PowerShell, depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# Module : https://learn.microsoft.com/fr-fr/training/modules/dynamic-sessions-azure-container-apps/
# Doc    : https://learn.microsoft.com/fr-fr/azure/container-apps/sessions
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Image de l'API exécutée dans chaque session (session-api/, C#, port 8080)
# -----------------------------------------------------------------------------
# Build dans Azure (ACR Tasks) avec un tag unique = Run ID
az acr build --registry acrai200david --image "session-api:{{.Run.ID}}" jour08-sessions-dynamiques-container-apps/session-api
#   -> Run ID: ddc was successful after 1m3s  => image acrai200david.azurecr.io/session-api:ddc
# Vérifier le tag dans l'ACR
az acr repository show-tags --name acrai200david --repository session-api --output table

# -----------------------------------------------------------------------------
# 2. Groupe de ressources et environnement (obligatoire pour un pool de type CustomContainer)
# -----------------------------------------------------------------------------
az group create --name rg-ai200-jour08 --location francecentral --query properties.provisioningState
#   --no-wait : la création (3-5 min) continue dans Azure, on peut fermer le terminal
#   rappel : 1 seul environnement Container Apps par région pour cet abonnement
az containerapp env create --name env-ai200-jour08 --resource-group rg-ai200-jour08 --location francecentral --no-wait
az containerapp env list --resource-group rg-ai200-jour08 --query "[].{nom:name, etat:properties.provisioningState}" --output table

# -----------------------------------------------------------------------------
# 3. Identité managée AFFECTÉE PAR L'UTILISATEUR + AcrPull (avant le pool : il tire l'image dès sa création)
# -----------------------------------------------------------------------------
$identityId = az identity create --name id-ai200-jour08 --resource-group rg-ai200-jour08 --location francecentral --query id --output tsv
$identityPrincipalId = az identity show --name id-ai200-jour08 --resource-group rg-ai200-jour08 --query principalId --output tsv
$registryId = az acr show --name acrai200david --query id --output tsv
#   --assignee-principal-type ServicePrincipal : évite la recherche dans Entra ID (identité toute neuve)
az role assignment create --assignee-object-id $identityPrincipalId --assignee-principal-type ServicePrincipal --role AcrPull --scope $registryId
#   vérification (la sortie de "create" n'a pas de champ roleDefinitionName, celle de "list" oui)
az role assignment list --assignee $identityPrincipalId --scope $registryId --query "[].roleDefinitionName" --output tsv

# -----------------------------------------------------------------------------
# 4. Pool de sessions de type conteneur personnalisé
# -----------------------------------------------------------------------------
#   1re tentative avec --mi-user-assigned $identityId EN PLUS de --registry-identity $identityId :
#     InvalidRequestContent "duplicate JSON property names" -> --registry-identity ajoute déjà l'identité au pool
az containerapp sessionpool create --name pool-ai200-jour08 --resource-group rg-ai200-jour08 --environment env-ai200-jour08 --location francecentral --container-type CustomContainer --image acrai200david.azurecr.io/session-api:ddc --target-port 8080 --registry-server acrai200david.azurecr.io --registry-identity $identityId --cpu 0.25 --memory 0.5Gi --max-sessions 5 --ready-sessions 1 --cooldown-period 300 --network-status EgressDisabled --query properties.poolManagementEndpoint
#   -> "https://pool-ai200-jour08.<domaine-environnement>.francecentral.azurecontainerapps.io"

# -----------------------------------------------------------------------------
# 5. Rôle "Azure ContainerApps Session Executor" à MON compte sur le pool (le rôle Propriétaire ne suffit pas)
# -----------------------------------------------------------------------------
$poolId = az containerapp sessionpool show --name pool-ai200-jour08 --resource-group rg-ai200-jour08 --query id --output tsv
$myId = az ad signed-in-user show --query id --output tsv
az role assignment create --assignee-object-id $myId --assignee-principal-type User --role "Azure ContainerApps Session Executor" --scope $poolId --output none
az role assignment list --assignee $myId --scope $poolId --query "[].roleDefinitionName" --output tsv

# -----------------------------------------------------------------------------
# 6. Client C# (session-client/) : jeton Entra (AzureCliCredential, audience https://dynamicsessions.io)
# -----------------------------------------------------------------------------
#   Navigateur sur l'adresse du pool -> "403 / Unauthenticated." : pas de jeton Bearer (authentification),
#   même si le rôle Session Executor est attribué (autorisation)
$env:SESSION_POOL_ENDPOINT = az containerapp sessionpool show --name pool-ai200-jour08 --resource-group rg-ai200-jour08 --query properties.poolManagementEndpoint --output tsv
dotnet run --project jour08-sessions-dynamiques-container-apps/session-client -- note alice "Note d'Alice"   # 200, conteneur A
dotnet run --project jour08-sessions-dynamiques-container-apps/session-client -- note bob "Note de Bob"       # 200, conteneur B (isolation)
dotnet run --project jour08-sessions-dynamiques-container-apps/session-client -- lire alice
#   -> 429 TooManyRequests "Error happened when allocating pod" : la session d'Alice n'existait plus,
#      le pool devait en attribuer une nouvelle et n'en avait pas de prête (erreur transitoire : GET relancé)
dotnet run --project jour08-sessions-dynamiques-container-apps/session-client -- sessions
#   -> seule "bob" ; expiresAt = createdAt + 300 s (--cooldown-period)
#   2e "lire alice" : 200, NOUVEAU conteneur, notes [] -> la note d'Alice est perdue
#   LEÇON : une session n'est PAS un stockage durable ; même identifier = parfois session neuve et vide
dotnet run --project jour08-sessions-dynamiques-container-apps/session-client -- lire bob    # ["Note de Bob"]
dotnet run --project jour08-sessions-dynamiques-container-apps/session-client -- stop bob    # "Session bob ... stopped."
dotnet run --project jour08-sessions-dynamiques-container-apps/session-client -- lire bob    # nouveau conteneur, notes []
