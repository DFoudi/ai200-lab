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

# -----------------------------------------------------------------------------
# 2. Panne volontaire : mauvais port cible de l'entrée (8000 -> 80)
# -----------------------------------------------------------------------------
az containerapp ingress update --name monapp --resource-group rg-ai200-jour06 --target-port 80
#   navigateur : "upstream connect error or disconnect/reset before headers"
#     -> le proxy (Envoy) devant l'app n'arrive pas à joindre le conteneur ("upstream") sur le port 80,
#        car l'API écoute sur 8000
#   PAS de nouvelle révision : l'entrée (ingress) est dans "configuration" (portée application)
#   révision : Provisioned / Running / Healthy, 2 réplicas -> le CONTENEUR va bien, c'est le CHEMIN RÉSEAU qui est cassé (piège)
#   (les sondes, créées au "create" sur le port 8000, n'ont pas changé : à vérifier au jour 6 suite)

# -----------------------------------------------------------------------------
# 3. Diagnostic
# -----------------------------------------------------------------------------
# 3.1 état des révisions (approvisionnement, exécution, santé, nombre de réplicas)
az containerapp revision list --name monapp --resource-group rg-ai200-jour06 --query "[].{revision:name, active:properties.active, approvisionnement:properties.provisioningState, execution:properties.runningState, sante:properties.healthState, replicas:properties.replicas}" --output table
#   monapp--0000001  True  Provisioned  Running  Healthy  2
#   réplica = une copie du conteneur en train de tourner (≈ une instance du plan App Service / un serveur d'une ferme IIS)

# 3.2 journaux SYSTÈME (la plateforme) : c'est là qu'est la vraie cause
#     (navigateur : "... delayed connect error: Connection refused" = personne n'écoute sur ce port)
az containerapp logs show --name monapp --resource-group rg-ai200-jour06 --type system --tail 30
#   "Probe of StartUp failed with status code: 1"   (Count 233 ... 240)
#   "Container monapp failed startup probe, will be restarted"
#   "Container 'monapp' was terminated ... reason 'ProbeFailure'"  -> Pulling image -> Started -> ... BOUCLE
#   sonde de démarrage PAR DÉFAUT : TCP sur le PORT CIBLE DE L'ENTRÉE (donc 80), période 1 s, seuil d'échec 240
#   "Healthy" dans revision list = résumé trompeur (un ancien réplica encore sain) -> lire les journaux système

# -----------------------------------------------------------------------------
# 4. Réparation : remettre le port cible de l'entrée sur le port d'écoute de l'API
# -----------------------------------------------------------------------------
az containerapp ingress update --name monapp --resource-group rg-ai200-jour06 --target-port 8000

# -----------------------------------------------------------------------------
# 5. Sondes et ressources
# -----------------------------------------------------------------------------
# 5.1 sondes définies dans la configuration ?
az containerapp show --name monapp --resource-group rg-ai200-jour06 --query "properties.template.containers[0].probes" --output json
#   -> VIDE : aucune sonde écrite. Avec l'entrée activée, Container Apps applique des sondes TCP PAR DÉFAUT
#      "en coulisse" sur le port cible de l'entrée (d'où la boucle de redémarrage avec le port 80)
#   Sonde HTTP personnalisée (ex. GET /health -> 200-399) : à définir en YAML / ARM / Bicep
#   Startup = a démarré ? (échec -> tué/redémarré) ; Liveness = toujours vivant ? (échec -> redémarré)
#   Readiness = prêt pour du trafic ? (échec -> plus de trafic, PAS redémarré)

# 5.2 taille des réplicas + nombre min/max
az containerapp update --name monapp --resource-group rg-ai200-jour06 --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 3
#   -> NOUVELLE révision monapp--0000002 : resources et scale sont dans "template" (portée révision)
#   CPU/RAM par paires imposées (0.25/0.5Gi, 0.5/1Gi, 1/2Gi...) ; ephemeralStorage suit (2Gi -> 1Gi)
#   min 1 = pas de démarrage à froid mais coût permanent ; max 3 = plafond de facture

# -----------------------------------------------------------------------------
# 6. Nettoyage (il ne reste que l'ACR)
# -----------------------------------------------------------------------------
$principalId = az containerapp identity show --name monapp --resource-group rg-ai200-jour06 --query principalId --output tsv
$registryId = az acr show --name acrai200david --query id --output tsv
az role assignment delete --assignee $principalId --role AcrPull --scope $registryId
#   piège : "--scope registryId" (sans $) -> Azure reçoit le TEXTE "registryId" -> erreur MissingSubscription
az role assignment list --assignee $principalId --scope $registryId --output table    # vide
az group delete --name rg-ai200-jour06 --yes --no-wait     # --no-wait : rend la main tout de suite
az group list --output table                               # à vérifier plus tard : rg-ai200-jour06 a disparu
