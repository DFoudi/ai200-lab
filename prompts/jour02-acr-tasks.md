# Prompt : Jour 2, ACR Tasks (version C#)

```
Je prépare la certification Microsoft AI-200. Tout le code du lab est en C# / .NET 10 (API ASP.NET Core avec controllers), jamais en Python.
C'est le jour 2 de mon plan : ACR Tasks.
Durée visée : environ 2 h, en deux séances (étapes 0 à 3, puis 4 à 8).
Aux jours précédents, j'ai créé le RG rg-ai200-socle, un ACR Basic et l'image monapp (v2 et latest) à partir de jour01-acr/app.
Relis jour01-acr/commands.sh et NOTES.md pour retrouver le nom de mon registre et le contexte. Le repo est déjà sur GitHub (DFoudi/ai200-lab, branche main).

Ton rôle : tu es mon guide, pas mon exécutant.
- Ne lance AUCUNE commande Azure (az) ni git push à ma place. Donne-moi la commande, explique chaque paramètre, puis attends que je la tape et que je te colle le résultat.
- Pour toute explication ou commande Azure, vérifie d'abord dans la documentation Microsoft Learn et donne-moi le lien de la page utilisée.
- Tu écris toi-même tout le code C# (app et tests) et la plomberie (dossiers, .csproj, Dockerfile, config), puis tu m'expliques brièvement ce qu'il fait : je me concentre sur Azure et l'AI-200. Le YAML de la task, sujet d'examen, tu me l'écris aussi, mais tu me l'expliques ligne par ligne. Pour les analogies CI, utilise Azure DevOps Pipelines (je ne maîtrise pas GitHub Actions).
- Avance étape par étape : une étape, je valide, puis la suivante.
- Ne me demande jamais de coller mon token GitHub dans la conversation. Fais-moi le mettre dans une variable d'environnement.

Déroulé de la séance :

0. Rappel en 5 lignes : quelle différence entre az acr build (quick task), az acr run (quick task depuis un fichier YAML) et az acr task create (tâche enregistrée avec déclencheurs) ?

1. Préparation : crée jour02-acr-tasks/ avec une copie de l'app du jour 1 dans app/, et un projet de tests xUnit dans tests/MonApp.Tests/ (packages xunit, Microsoft.NET.Test.Sdk, xunit.runner.visualstudio, Microsoft.AspNetCore.Mvc.Testing). Ajoute au Dockerfile un stage "test" (image sdk:10.0) qui lance dotnet test. Donne-moi le squelette de tests/MonApp.Tests/HealthTests.cs pour tester GET /health avec WebApplicationFactory<Program> : j'écris le test moi-même.

2. Task multi-étapes : guide-moi pour écrire jour02-acr-tasks/acr-task.yaml :
   - build de l'image de test (--target test)
   - exécution des tests (cmd) dans le conteneur de test qui vient d'être construit
   - build de l'image finale taguée $Registry/monapp:{{.Run.ID}}
   - push de l'image finale
   Explique les variables disponibles ($Registry, {{.Run.ID}}, etc.) et ce qui se passe si l'étape de test échoue.

3. Quick run : je lance la task avec az acr run sur le fichier YAML (contexte jour02-acr-tasks). Ensuite, je casse volontairement le test, je relance et j'observe que le push n'a pas lieu. Je répare.

4. Tâche déclenchée par commit :
   - je commite et pousse le dossier jour02-acr-tasks (vérifie le .gitignore : bin/, obj/, aucun secret)
   - explique quels droits donner au token GitHub (PAT) d'après la doc officielle
   - guide-moi pour az acr task create avec --context pointant sur mon repo (branche main, dossier jour02-acr-tasks) et le fichier acr-task.yaml
   - je fais un petit commit, puis je vérifie avec az acr task list-runs et az acr task logs que le build s'est déclenché tout seul

5. Autres déclencheurs :
   - ajoute un déclencheur planifié (timer) avec une expression cron, puis lance la task à la main avec az acr task run
   - explique en 3 lignes le déclencheur sur mise à jour de l'image de base, sans le mettre en place

6. Nettoyage : guide-moi pour supprimer la task (et donc le webhook GitHub) avec az acr task delete, puis révoquer le PAT. Vérifie avec moi qu'il ne reste rien qui tourne ou qui coûte, hors l'ACR du socle.

7. Notes : crée jour02-acr-tasks/commands.sh avec toutes les commandes tapées, commentées. Ajoute une section "Jour 2" dans NOTES.md avec les 5 points clés pour l'examen, et complète POINTS-A-REVOIR.md.

8. Quiz : pose-moi 3 questions de type examen AI-200 sur ACR Tasks, une par une. Attends ma réponse avant de corriger. Mélange une question de choix de commande, une question sur la syntaxe YAML et une question sur les déclencheurs.
```

## Règle pour les prochains prompts

Si un prompt contient du Python par erreur, il est automatiquement traduit en C# :

| Python | C# / .NET |
|---|---|
| FastAPI | ASP.NET Core (controllers) |
| uvicorn | Kestrel (`ASPNETCORE_HTTP_PORTS`) |
| `requirements.txt` | `<PackageReference>` dans le `.csproj` |
| pytest | xUnit |
| `TestClient` FastAPI / httpx | `WebApplicationFactory<Program>` + `HttpClient` |
| `python:3.12-slim` | `mcr.microsoft.com/dotnet/sdk:10.0` (build/test) + `aspnet:10.0` (runtime) |
| SDK Azure pour Python | SDK Azure pour .NET (`Azure.*`) |
