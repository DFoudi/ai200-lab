// API lancée DANS CHAQUE SESSION d'un pool de sessions dynamiques (type CustomContainer).
//
// Chaque session est un conteneur isolé (bac à sable Hyper-V) attribué à un "identifier".
// Les notes sont gardées EN MÉMOIRE : la session "alice" et la session "bob" sont deux conteneurs
// différents, donc chacune ne voit que ses propres notes. Quand la session expire
// (--cooldown-period sans requête), le conteneur est détruit et ses notes disparaissent.
//
// Le paramètre ?identifier=... est lu par la plateforme pour choisir la session ;
// l'API ne s'en sert que pour l'afficher.

using System.Collections.Concurrent;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var notes = new ConcurrentQueue<string>();
var startedAt = DateTimeOffset.UtcNow;
var sessionHost = Environment.MachineName; // nom du conteneur : différent pour chaque session

// Informations sur la session qui répond
app.MapGet("/", (string? identifier) => Results.Ok(new
{
    identifier,
    conteneur = sessionHost,
    demarreA = startedAt,
    nombreDeNotes = notes.Count
}));

// Ajoute une note dans CETTE session
app.MapPost("/notes", (NoteRequest request, string? identifier) =>
{
    if (string.IsNullOrWhiteSpace(request.Texte))
        return Results.BadRequest(new { erreur = "Le champ 'texte' est obligatoire." });

    notes.Enqueue(request.Texte);
    return Results.Ok(new { identifier, conteneur = sessionHost, notes });
});

// Lit les notes de CETTE session
app.MapGet("/notes", (string? identifier) =>
    Results.Ok(new { identifier, conteneur = sessionHost, notes }));

// Sonde de santé
app.MapGet("/health", () => Results.Ok(new { statut = "ok" }));

app.Run();

record NoteRequest(string Texte);
