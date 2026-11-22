#!/usr/bin/env bash
# =============================================================================
# Jour 7 : mettre à l'échelle des conteneurs dans Azure Container Apps (parcours 2, module 3)
#          règle HTTP + test de charge C#, puis règle KEDA sur une file d'attente
# Commandes tapées pendant les séances (à partir du 22 novembre 2026), dans l'ordre.
# Terminal : Windows PowerShell, depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# Doc : https://learn.microsoft.com/fr-fr/azure/container-apps/scale-app?pivots=azure-cli
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Test de charge en C# (load-test/) : N boucles parallèles qui enchaînent des GET
# -----------------------------------------------------------------------------
dotnet build jour07-mise-a-echelle-container-apps/load-test
#   usage : dotnet run --project jour07-mise-a-echelle-container-apps/load-test -- <url> [secondes] [parallelisme]

# -----------------------------------------------------------------------------
# 1. Environnement
# -----------------------------------------------------------------------------
az group create --name rg-ai200-jour07 --location francecentral
az containerapp env create --name env-ai200-jour07 --resource-group rg-ai200-jour07 --location francecentral
#   Faute de frappe à la 1re tentative ("sv-ai200-jour07") -> un environnement NE SE RENOMME PAS :
az containerapp env delete --name sv-ai200-jour07 --resource-group rg-ai200-jour07 --yes --no-wait
#   Recréer tout de suite a échoué :
#     MaxNumberOfRegionalEnvironmentsInSubExceeded : 1 seul environnement Container Apps par région
#     pour cet abonnement, et un environnement "ScheduledForDelete"/"Deleting" compte encore
az containerapp env list --resource-group rg-ai200-jour07 --query "[].{nom:name, etat:properties.provisioningState}" --output table
#   attendre que la liste soit vide, puis relancer "env create" avec le bon nom
#   l'environnement est resté "ScheduledForDelete" plus de 15 min (on ne peut pas l'accélérer)
#   contournement tenté : une autre région ->
#     az containerapp env create --name env-ai200-jour07 --resource-group rg-ai200-jour07 --location westeurope
#     ÉCHEC : RequestDisallowedByAzure "The selected region is currently not accepting new customers"
#     (région saturée, fermée aux nouveaux abonnements) -> on reste en francecentral, séance suivante
