#!/usr/bin/env bash
# =============================================================================
# Jour 1 : Azure Container Registry (ACR)
# Commandes tapées pendant la séance (3-4 novembre 2026), dans l'ordre.
# Terminal : bash (MSYS2 / Git Bash), depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Environnement
# -----------------------------------------------------------------------------

# Installer l'Azure CLI (PowerShell). Ensuite, OUVRIR UN NOUVEAU TERMINAL (PATH)
# winget install --exact --id Microsoft.AzureCLI

# Installer le SDK .NET 10 (PowerShell). Penser à valider la fenêtre UAC
# winget install --exact --id Microsoft.DotNet.SDK.10

az version                                     # version de la CLI et de ses extensions
az login                                       # connexion (navigateur) : répondre avec Entrée au choix d'abonnement
az account show --output table                 # abonnement actif (doit être Enabled)
az extension add --name containerapp --upgrade # extension Container Apps (préversion), pour les jours suivants
git --version
dotnet --list-sdks                             # doit lister un SDK 10.x

# Vérifier le budget (portée = abonnement). Il a été créé dans le portail :
# Abonnements > Azure subscription > Gestion des coûts > Budgets
az consumption budget list --output table

# -----------------------------------------------------------------------------
# 1. Application (test en local)
# -----------------------------------------------------------------------------
cd /c/Dev/ai200-lab/jour01-acr/app
export ASPNETCORE_HTTP_PORTS=8000              # Kestrel écoute sur le port 8000
export DB_PASSWORD=SuperSecret123              # faux secret, fourni par l'environnement (jamais dans le code)
dotnet run                                     # puis http://localhost:8000/ , /secret , /health  (Ctrl+C pour arrêter)
cd /c/Dev/ai200-lab

# -----------------------------------------------------------------------------
# 2. Socle Azure : resource group + ACR
# -----------------------------------------------------------------------------

# Resource group = le "dossier" logique (gratuit), dans la région France Central
az group create --name rg-ai200-socle --location francecentral

# Abonnement neuf : activer UNE FOIS le fournisseur ACR (sinon MissingSubscriptionRegistration)
az provider register --namespace Microsoft.ContainerRegistry
az provider show --namespace Microsoft.ContainerRegistry --query registrationState --output tsv   # Registering -> Registered

# Créer l'ACR. Nom unique au monde, minuscules + chiffres uniquement. SKU Basic (~5 $/mois)
az acr create --resource-group rg-ai200-socle --name acrai200david --sku Basic --location francecentral

# Afficher l'essentiel (requête JMESPath) : loginServer = acrai200david.azurecr.io, admin = False
az acr show --name acrai200david --query "{nom:name, adresse:loginServer, sku:sku.name, admin:adminUserEnabled}" --output table

# -----------------------------------------------------------------------------
# 3. Build dans le cloud (ACR Tasks), sans Docker local
# -----------------------------------------------------------------------------
# Équivaut à : docker build + az acr login + docker push.
# Le dossier (contexte) est compressé et envoyé ; .dockerignore exclut bin/ et obj/.
az acr build --registry acrai200david --image monapp:v1 ./jour01-acr/app

# -----------------------------------------------------------------------------
# 4. Versionnage : une image, deux tags
# -----------------------------------------------------------------------------
# (APP_VERSION passé de "v1" à "v2" dans le Dockerfile avant ce build)
az acr build --registry acrai200david --image monapp:v2 --image monapp:latest ./jour01-acr/app

# Bonus (pas encore utilisé) : passer la version au build au lieu de modifier le Dockerfile
# Dockerfile : ARG APP_VERSION=dev  puis  ENV APP_VERSION=$APP_VERSION
# az acr build --registry acrai200david --build-arg APP_VERSION=v3 --image monapp:v3 ./jour01-acr/app

# -----------------------------------------------------------------------------
# 5. Gestion des images
# -----------------------------------------------------------------------------
az acr repository list --name acrai200david --output table                          # repositories : monapp
az acr repository show-tags --name acrai200david --repository monapp --output table # tags : latest, v1, v2
az acr manifest list-metadata --registry acrai200david --name monapp --output table # manifests = images réelles (2)

# Tags par digest : v2 et latest partagent le même digest
az acr manifest list-metadata --registry acrai200david --name monapp --query "[].{tags:join(', ', tags), digest:digest}" --output table
# Si une image n'a aucun tag (tags = null), join() échoue : afficher en JSON à la place
az acr manifest list-metadata --registry acrai200david --name monapp --query "[].{tags:tags, digest:digest}" --output json

# UNTAG : retire seulement l'étiquette. L'image reste stockée (tags: null) et facturée
az acr repository untag --name acrai200david --image monapp:v1

# DELETE : supprime l'image (le manifest) et TOUS ses tags. "@" = par digest, ":" = par tag
az acr repository delete --name acrai200david --image monapp@sha256:e4bcd9fcc66e0fb56de4d65f602dcc824c391b6ce454de110660393b622b4525 --yes
# ⚠️ delete --image monapp:v2 supprimerait aussi latest (même digest)
