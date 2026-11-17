// SIDE-CAR : un faux "serveur de modèle d'IA".
// Il n'est PAS joignable depuis Internet : seul le conteneur principal (chat-api)
// l'appelle, via http://localhost:5000, car les deux conteneurs partagent le même réseau.
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

var app = builder.Build();

app.MapControllers();

app.Run();
