// Client du pool de sessions dynamiques (type CustomContainer) : joue le rôle du BACK-END
// d'une application d'IA qui envoie le travail de chaque utilisateur dans SA session isolée.
//
// Authentification : jeton Microsoft Entra pour l'audience https://dynamicsessions.io,
// obtenu à partir de la connexion "az login" (AzureCliCredential). Mon compte doit avoir le rôle
// "Azure ContainerApps Session Executor" sur le pool. Le jeton n'est JAMAIS affiché.
//
// Utilisation (adresse du pool dans la variable d'environnement SESSION_POOL_ENDPOINT) :
//   dotnet run -- note <identifier> "<texte>"   -> POST /notes?identifier=...   (ajoute une note dans la session)
//   dotnet run -- lire <identifier>             -> GET  /notes?identifier=...   (lit les notes de la session)
//   dotnet run -- sessions                      -> POST /.management/listSessions
//   dotnet run -- stop <identifier>             -> POST /.management/stopSession
//   dotnet run -- sans-jeton <identifier>       -> même appel que "lire" mais SANS jeton (refus attendu)
//
// Docs : https://learn.microsoft.com/fr-fr/azure/container-apps/session-pool
//        https://learn.microsoft.com/fr-fr/training/modules/dynamic-sessions-azure-container-apps/4-execute-code-exchange-files

using System.Net.Http.Headers;
using System.Net.Http.Json;
using Azure.Core;
using Azure.Identity;

const string ManagementApiVersion = "2025-02-02-preview";

var endpoint = Environment.GetEnvironmentVariable("SESSION_POOL_ENDPOINT")?.TrimEnd('/');
if (string.IsNullOrWhiteSpace(endpoint) || args.Length == 0)
{
    Console.WriteLine("Définir SESSION_POOL_ENDPOINT puis : dotnet run -- note|lire|sessions|stop|sans-jeton [identifier] [texte]");
    return 1;
}

var command = args[0];
var identifier = args.Length > 1 ? Uri.EscapeDataString(args[1]) : null;

if (command is "note" or "lire" or "stop" or "sans-jeton" && identifier is null)
{
    Console.WriteLine($"La commande '{command}' a besoin d'un identifier.");
    return 1;
}

// Délai explicite (recommandé par le module, unité 5) : on ne reste pas bloqué si une session ne répond pas
using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

if (command != "sans-jeton")
{
    // Jeton pour l'audience des sessions dynamiques ; redemandé à chaque exécution du programme
    var credential = new AzureCliCredential();
    AccessToken token = await credential.GetTokenAsync(
        new TokenRequestContext(["https://dynamicsessions.io/.default"]));
    http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
}

HttpResponseMessage response = command switch
{
    // Requêtes transmises par le pool à NOTRE API (port 8080) dans la session choisie par "identifier"
    "note" => await http.PostAsJsonAsync($"{endpoint}/notes?identifier={identifier}",
                  new { texte = args.Length > 2 ? args[2] : "note sans texte" }),
    "lire" or "sans-jeton" => await http.GetAsync($"{endpoint}/notes?identifier={identifier}"),

    // API de gestion du pool (préfixe .management)
    "sessions" => await http.PostAsync(
                  $"{endpoint}/.management/listSessions?skip=0&api-version={ManagementApiVersion}", content: null),
    "stop" => await http.PostAsync(
                  $"{endpoint}/.management/stopSession?api-version={ManagementApiVersion}&identifier={identifier}", content: null),

    _ => throw new ArgumentException($"Commande inconnue : {command}")
};

Console.WriteLine($"HTTP {(int)response.StatusCode} {response.StatusCode}");
Console.WriteLine(await response.Content.ReadAsStringAsync());
return response.IsSuccessStatusCode ? 0 : 1;
