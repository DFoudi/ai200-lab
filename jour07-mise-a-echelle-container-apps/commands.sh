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
#   Séance du soir (22/11, 20h53) : "sv-ai200-jour07" enfin supprimé -> env create OK
#   (avertissement jaune sur --logs-destination : simple annonce d'un futur changement de valeur par défaut)

# -----------------------------------------------------------------------------
# 2. Container app avec règle de mise à l'échelle HTTP
# -----------------------------------------------------------------------------
#   --min-replicas 0        : descend à 0 réplica sans trafic (0 coût de calcul)
#   --max-replicas 5        : plafond
#   --scale-rule-type http  : déclencheur = requêtes HTTP simultanées
#   --scale-rule-http-concurrency 1 : 1 requête simultanée par réplica (défaut : 10)
az containerapp create --name monapp --resource-group rg-ai200-jour07 --environment env-ai200-jour07 --image acrai200david.azurecr.io/monapp:dd9 --registry-server acrai200david.azurecr.io --registry-identity system --ingress external --target-port 8000 --min-replicas 0 --max-replicas 5 --scale-rule-name http-rule --scale-rule-type http --scale-rule-http-concurrency 1 --query properties.configuration.ingress.fqdn

# -----------------------------------------------------------------------------
# 3. Test de charge et observation des réplicas (2 onglets PowerShell)
# -----------------------------------------------------------------------------
# Onglet 1 : charge 120 s, 20 requêtes simultanées
dotnet run --project jour07-mise-a-echelle-container-apps/load-test -- https://<fqdn>/ 120 20
#   résultat : ~380 requêtes/s, 0 erreur
# Onglet 2 : compter les réplicas (avant, pendant, après)
az containerapp replica list --name monapp --resource-group rg-ai200-jour07 --query "[].name" --output table
#   avant : 1 réplica (gardé après la création, pas encore redescendu)
#   pendant : 5 réplicas = 20 requêtes / concurrence 1 = 20 voulus, plafonnés à 5
#   tous dans la même révision 0000001 : la mise à l'échelle ajoute des copies, pas de révision
#   après ~300 s sans trafic (refroidissement) : retour à 0 réplica
