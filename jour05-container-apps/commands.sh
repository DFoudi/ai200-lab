#!/usr/bin/env bash
# =============================================================================
# Jour 5 : Azure Container Apps, environnement, secrets et RÉVISIONS (parcours 2)
# Commandes tapées pendant la séance du 18 novembre 2026, dans l'ordre.
# Terminal : Windows PowerShell, depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# Doc : https://learn.microsoft.com/fr-fr/azure/container-apps/revisions
#       https://learn.microsoft.com/fr-fr/azure/container-apps/traffic-splitting
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Préparation
# -----------------------------------------------------------------------------
az extension add --name containerapp --upgrade        # extension CLI (versions préversion b5 -> b6 : normal)
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights   # Log Analytics
az provider show --namespace Microsoft.App --query registrationState --output tsv                    # Registered
az provider show --namespace Microsoft.OperationalInsights --query registrationState --output tsv    # Registering -> Registered
az acr repository show-tags --name acrai200david --repository monapp --output table   # tag unique dd9 ; l'API écoute sur 8000

# -----------------------------------------------------------------------------
# 2. Environnement (≈ le "plan" d'App Service)
# -----------------------------------------------------------------------------
az group create --name rg-ai200-jour05 --location francecentral
az containerapp env create --name env-ai200-jour05 --resource-group rg-ai200-jour05 --location francecentral
#   crée AUTOMATIQUEMENT un espace de travail Log Analytics (workspace-rgai200jour05...) : journaux de toutes les apps
#   "environmentMode": "WorkloadProfiles" + profil "Consumption" (serverless, paiement à l'usage)
#   "defaultDomain": "<mot>-<id>.francecentral.azurecontainerapps.io"

# -----------------------------------------------------------------------------
# 3. Première container app : ACR + identité managée + entrée externe + variables
# -----------------------------------------------------------------------------
az containerapp create --name monapp --resource-group rg-ai200-jour05 --environment env-ai200-jour05 --image acrai200david.azurecr.io/monapp:dd9 --registry-server acrai200david.azurecr.io --registry-identity system --ingress external --target-port 8000 --env-vars "APP_MESSAGE=Bonjour depuis Container Apps" APP_VERSION=1 --query properties.configuration.ingress.fqdn
#   --registry-identity system : la CLI crée l'identité managée ET l'attribution AcrPull sur l'ACR (dans rg-ai200-socle)
#   -> 2 révisions : 1 avec l'image publique mcr.microsoft.com/k8se/quickstart (l'identité n'existe pas encore),
#      puis 1 avec monapp:dd9
#   Jour 3 (App Service), il fallait 4 commandes : identity assign + role assignment AcrPull
#      + acrUseManagedIdentityCreds + WEBSITES_PORT
#   Piège rencontré : APP__VERSION (2 underscores) -> mon code ne trouve pas APP_VERSION -> affiche "jour2-trigger"
#   Pour modifier une app existante : "az containerapp update" (relancer "create" refait 2 révisions)
az containerapp update --name monapp --resource-group rg-ai200-jour05 --set-env-vars APP_VERSION=1 --remove-env-vars APP__VERSION

# Révisions : sans --all, seules les ACTIVES apparaissent
az containerapp revision list --name monapp --resource-group rg-ai200-jour05 --all --query "[].{revision:name, active:properties.active, trafic:properties.trafficWeight, image:properties.template.containers[0].image}" --output table

# -----------------------------------------------------------------------------
# 4. Secrets (portée APPLICATION)
# -----------------------------------------------------------------------------
az containerapp secret set --name monapp --resource-group rg-ai200-jour05 --secrets db-pass=Faux-MotDePasse-123
#   -> PAS de nouvelle révision ; avertissement : "must be restarted in order for secret changes to take effect"
az containerapp update --name monapp --resource-group rg-ai200-jour05 --set-env-vars DB_PASSWORD=secretref:db-pass
#   -> NOUVELLE révision (0000004) : une variable d'environnement est de portée révision ; /secret -> "Fau***"
# Redémarrer une révision (pour relire un secret modifié) :
#   az containerapp revision restart --name monapp --resource-group rg-ai200-jour05 --revision monapp--0000004
# Référence Key Vault (non mise en place) : identité managée + rôle "Key Vault Secrets User" sur le coffre
#   --secrets "db-pass=keyvaultref:https://<coffre>.vault.azure.net/secrets/<nom>,identityref:<id-identité-utilisateur>"
#   sans version dans l'URI -> nouvelle version récupérée sous 30 min (App Service : 24 h)

# -----------------------------------------------------------------------------
# 5. Révisions : mode multiple, canary 80/20, label, bascule
# -----------------------------------------------------------------------------
az containerapp revision set-mode --name monapp --resource-group rg-ai200-jour05 --mode multiple
az containerapp ingress traffic set --name monapp --resource-group rg-ai200-jour05 --revision-weight monapp--0000004=100
#   "épingler" : sinon la règle "latestRevision: true" donnerait 100 % à la prochaine révision dès sa création
az containerapp update --name monapp --resource-group rg-ai200-jour05 --revision-suffix v2 --set-env-vars APP_VERSION=2
#   -> révision monapp--v2, active, 0 % de trafic ; URL directe : https://monapp--v2.<domaine>/
az containerapp ingress traffic set --name monapp --resource-group rg-ai200-jour05 --revision-weight monapp--0000004=80 monapp--v2=20
1..20 | ForEach-Object { (Invoke-RestMethod https://monapp.lemonriver-76a8e214.francecentral.azurecontainerapps.io/).version } | Group-Object | Select-Object Name, Count
#   résultat : 1 -> 14, 2 -> 6 (répartition aléatoire par requête)
az containerapp revision label add --name monapp --resource-group rg-ai200-jour05 --label beta --revision monapp--v2
#   URL du label (3 tirets) : https://monapp---beta.<domaine>/ -> toujours la v2 (10/10)
#   un label se DÉPLACE d'une révision à l'autre en gardant la même URL
az containerapp ingress traffic set --name monapp --resource-group rg-ai200-jour05 --revision-weight monapp--v2=100 monapp--0000004=0
az containerapp revision deactivate --name monapp --resource-group rg-ai200-jour05 --revision monapp--0000004
#   d'abord 0 % de trafic, ENSUITE désactiver ; réactivable avec "az containerapp revision activate"

# -----------------------------------------------------------------------------
# 6. Nettoyage (il ne reste que l'ACR)
# -----------------------------------------------------------------------------
$principalId = az containerapp identity show --name monapp --resource-group rg-ai200-jour05 --query principalId --output tsv
$registryId = az acr show --name acrai200david --query id --output tsv
az role assignment list --assignee $principalId --scope $registryId --output table    # AcrPull créé automatiquement par la CLI
az role assignment delete --assignee $principalId --role AcrPull --scope $registryId
az group delete --name rg-ai200-jour05 --yes     # environnement + app + Log Analytics
az group list --output table
az resource list --output table
