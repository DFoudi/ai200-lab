using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

namespace MonApp.Tests;

// IClassFixture<WebApplicationFactory<Program>> :
// xUnit crée UNE fois une WebApplicationFactory, qui démarre ton API EN MÉMOIRE
// (pas de port, pas de Kestrel réel), et l'injecte dans le constructeur.
public class HealthTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public HealthTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetHealth_RenvoieStatusOk()
    {
        // TODO 1 (Arrange) : créer un HttpClient relié à l'API en mémoire
        //                    -> la factory possède une méthode pour ça
        HttpClient client = _factory.CreateClient();

        // ACT : on appelle GET /health
        HttpResponseMessage response = await client.GetAsync("/health");

        // ASSERT 1 : le code HTTP doit être 200
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        // ASSERT 2 : on lit le corps de la réponse, il doit contenir "ok"
        string body = await response.Content.ReadAsStringAsync();
        Assert.Contains("ok", body);
    }
}
