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
