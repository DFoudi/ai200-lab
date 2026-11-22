// Test de charge minimal : envoie des requêtes HTTP EN PARALLÈLE pendant une durée donnée,
// pour déclencher la règle de mise à l'échelle HTTP de la container app.
//
// Utilisation :
//   dotnet run --project jour07-mise-a-echelle-container-apps/load-test -- <url> [secondes] [parallelisme]
//   ex. : dotnet run --project jour07-mise-a-echelle-container-apps/load-test -- https://monapp.<domaine>/ 120 20

using System.Diagnostics;

if (args.Length < 1)
{
    Console.WriteLine("Usage : dotnet run -- <url> [secondes=120] [parallelisme=20]");
    return;
}

var url = args[0];
var durationSeconds = args.Length > 1 ? int.Parse(args[1]) : 120;
var parallelism = args.Length > 2 ? int.Parse(args[2]) : 20;

using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(durationSeconds));

var ok = 0;
var errors = 0;
var stopwatch = Stopwatch.StartNew();

Console.WriteLine($"Charge sur {url} pendant {durationSeconds} s, {parallelism} requêtes simultanées...");

// "parallelism" boucles qui tournent en même temps : chacune enchaîne les requêtes sans pause.
// Il y a donc en permanence ~"parallelism" requêtes en cours -> la règle HTTP (concurrence 1)
// demande jusqu'à "parallelism" réplicas, plafonnés par --max-replicas.
var workers = Enumerable.Range(0, parallelism).Select(async _ =>
{
    while (!cts.IsCancellationRequested)
    {
        try
        {
            using var response = await http.GetAsync(url, cts.Token);
            if (response.IsSuccessStatusCode) Interlocked.Increment(ref ok);
            else Interlocked.Increment(ref errors);
        }
        catch (OperationCanceledException) { break; }
        catch (HttpRequestException) { Interlocked.Increment(ref errors); }
    }
}).ToList();

// Affichage de la progression toutes les 10 secondes
var progress = Task.Run(async () =>
{
    while (!cts.IsCancellationRequested)
    {
        try { await Task.Delay(TimeSpan.FromSeconds(10), cts.Token); }
        catch (OperationCanceledException) { break; }
        Console.WriteLine($"  {stopwatch.Elapsed.TotalSeconds,5:0} s : {ok} OK, {errors} erreurs");
    }
});

await Task.WhenAll(workers);
await progress;

Console.WriteLine($"Terminé en {stopwatch.Elapsed.TotalSeconds:0} s : {ok} requêtes OK, {errors} erreurs.");
