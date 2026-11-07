#!/usr/bin/env bash
# =============================================================================
# Jour 2 : ACR Tasks (build + tests + push automatisés dans le cloud)
# Commandes tapées pendant les séances (5, 6 et 7 novembre 2026), dans l'ordre.
# Terminal : PowerShell ou bash, depuis C:\Dev\ai200-lab
# Ce fichier est un aide-mémoire : ne pas l'exécuter d'un bloc.
# Doc : https://learn.microsoft.com/fr-fr/azure/container-registry/container-registry-tasks-overview
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Tests en local (avant de les envoyer dans le cloud)
# -----------------------------------------------------------------------------
dotnet test jour02-acr-tasks/tests/MonApp.Tests   # xUnit + WebApplicationFactory : GET /health doit renvoyer 200 + "ok"

# -----------------------------------------------------------------------------
# 2. Quick task multi-étapes : on envoie le dossier local + le YAML à ACR
#    (build-tests -> run-tests -> build-image -> push-image)
# -----------------------------------------------------------------------------
az acr run --registry acrai200david --file acr-task.yaml ./jour02-acr-tasks
#   dd4 : OK -> monapp:dd4 poussée
#   dd5 : /health renvoyait "ko" -> tests en échec -> task arrêtée, AUCUN push
#   dd6 : corrigé -> monapp:dd6 poussée

az acr repository show-tags --name acrai200david --repository monapp --output table   # dd5 absent = garde-fou OK

# -----------------------------------------------------------------------------
# 3. Publier le code (ACR lira le code sur GitHub, plus sur le PC)
# -----------------------------------------------------------------------------
git add jour02-acr-tasks prompts POINTS-A-REVOIR.md
git commit -m "Jour 2 : ACR Tasks - tests xUnit et task multi-etapes"
git push

# -----------------------------------------------------------------------------
# 4. Task enregistrée + déclencheur par commit (MS Learn utilise GitHub ici)
# -----------------------------------------------------------------------------
# PAT GitHub (classic), 7 jours. Dépôt PRIVÉ -> scope "repo" (public : repo:status + public_repo)
# Ne jamais le coller dans un chat / une capture. Saisie sans historique (PowerShell) :
#   $env:GIT_PAT = Read-Host "Colle ton PAT"
#   $env:GIT_PAT.Length          # 40
# Équivalent bash : read -s GIT_PAT && export GIT_PAT

az acr task create \
  --registry acrai200david \
  --name monapp-ci \
  --context https://github.com/DFoudi/ai200-lab.git#main:jour02-acr-tasks \
  --file acr-task.yaml \
  --git-access-token $GIT_PAT          # PowerShell : $env:GIT_PAT
# -> crée la task ET un webhook GitHub (Settings > Webhooks : frc-acr-build-triggerservice…)

az acr task list-runs --registry acrai200david --output table   # photo « avant »
git add jour02-acr-tasks/Dockerfile                              # APP_VERSION="jour2-trigger"
git commit -m "Jour 2 : test du declencheur ACR Tasks par commit"
git push
az acr task list-runs --registry acrai200david --output table   # dd7 : TASK=monapp-ci, TRIGGER=Commit
az acr task logs --registry acrai200david                        # logs du dernier run
az acr repository show-tags --name acrai200david --repository monapp --output table   # dd7 présent

# -----------------------------------------------------------------------------
# 5. Déclencheur horaire (timer) + lancement manuel d'une task enregistrée
# -----------------------------------------------------------------------------
# Cron ACR : 5 champs "minute heure jour mois jour-semaine", en UTC (Paris = UTC+1 en hiver)
az acr task timer add --name monapp-ci --registry acrai200david --timer-name test-soir --schedule "40 17 * * *"
az acr task timer list --name monapp-ci --registry acrai200david

az acr task run --name monapp-ci --registry acrai200david        # dd8 : TRIGGER=Manual (code lu sur GitHub)
az acr task list-runs --name monapp-ci --registry acrai200david --output table   # après 17h40 UTC : TRIGGER=Timer

# Le déclencheur d'image de base est activé PAR DÉFAUT (baseImageTrigger) :
# ACR surveille dotnet/sdk:10.0 et dotnet/aspnet:10.0 et reconstruit si leur digest change.

# -----------------------------------------------------------------------------
# 6. Nettoyage (garder l'ACR, supprimer la task, révoquer le PAT)
# -----------------------------------------------------------------------------
az acr task delete --name monapp-ci --registry acrai200david     # supprime aussi le webhook GitHub (F5 pour le voir disparaître)
az acr task list --registry acrai200david --output table         # doit être vide
# Puis sur GitHub : Settings > Developer settings > Personal access tokens > acr-tasks-ai200 > Delete
