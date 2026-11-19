#!/usr/bin/env bash
# =============================================================================
# Jour 6 : gérer des conteneurs dans Azure Container Apps (parcours 2, module 2)
#          diagnostic d'un déploiement en échec, journaux, sondes, ressources
# Commandes tapées pendant les séances (19 et 20 novembre 2026), dans l'ordre.
# Terminal : Windows PowerShell, depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# Doc : https://learn.microsoft.com/fr-fr/training/modules/manage-containers-azure-container-apps/
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Environnement + container app (comme au jour 5, en plus court)
# -----------------------------------------------------------------------------
az group create --name rg-ai200-jour06 --location francecentral
az containerapp env create --name env-ai200-jour06 --resource-group rg-ai200-jour06 --location francecentral
#   "env" dans la commande = l'ENVIRONNEMENT (≈ plan App Service) ; sans "env" = la container app (≈ application web)

az containerapp create --name monapp --resource-group rg-ai200-jour06 --environment env-ai200-jour06 --image acrai200david.azurecr.io/monapp:dd9 --registry-server acrai200david.azurecr.io --registry-identity system --ingress external --target-port 8000 --env-vars APP_VERSION=1 --query properties.configuration.ingress.fqdn
#   -> https://monapp.greenplant-108f850c.francecentral.azurecontainerapps.io/
#   -> {"message":"Bonjour depuis ACR Tasks","version":"1"}
#      message = valeur par défaut gravée dans l'image (pas de APP_MESSAGE), version = variable APP_VERSION
#   Laissée en place pour la nuit : plan Consommation, pas de coût fixe, l'app descend à 0 réplica sans trafic
