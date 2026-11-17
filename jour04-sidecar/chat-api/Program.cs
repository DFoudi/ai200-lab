// CONTENEUR PRINCIPAL : l'API exposée sur Internet.
// Elle appelle le side-car "model-server" via localhost.
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Adresse du side-car, lue dans la configuration (variable d'environnement MODEL_URL).
// Valeur par défaut : http://localhost:5000 -> fonctionne en local ET dans App Service,
// car le principal et le side-car partagent le même réseau.
var modelUrl = builder.Configuration["MODEL_URL"] ?? "http://localhost:5000";

builder.Services.AddHttpClient("model", client =>
{
    client.BaseAddress = new Uri(modelUrl);
    client.Timeout = TimeSpan.FromSeconds(10);
});

var app = builder.Build();

app.MapControllers();

app.Run();
