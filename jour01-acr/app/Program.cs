var builder = WebApplication.CreateBuilder(args);

// API "classique" : on enregistre les controllers (pas de Minimal API)
builder.Services.AddControllers();

var app = builder.Build();

// Pas de HTTPS dans le conteneur : TLS sera terminé par la plateforme (Container Apps, etc.)
app.MapControllers();

app.Run();
