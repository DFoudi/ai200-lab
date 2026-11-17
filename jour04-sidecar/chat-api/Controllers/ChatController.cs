using Microsoft.AspNetCore.Mvc;

namespace ChatApi.Controllers;

[ApiController]
public class ChatController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<ChatController> _logger;

    public ChatController(IHttpClientFactory httpClientFactory, ILogger<ChatController> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    // GET /chat?question=Bonjour
    // L'API principale transmet la question au side-car (POST http://localhost:5000/generate).
    [HttpGet("/chat")]
    public async Task<IActionResult> Chat([FromQuery] string question = "Bonjour")
    {
        var client = _httpClientFactory.CreateClient("model");

        try
        {
            var response = await client.PostAsJsonAsync("/generate", new { prompt = question });
            response.EnsureSuccessStatusCode();

            var answer = await response.Content.ReadFromJsonAsync<ModelAnswer>();
            return Ok(new { question, answer?.Model, answer?.Reply, servedBy = "chat-api -> model-server (side-car)" });
        }
        catch (HttpRequestException ex)
        {
            // Symptôme typique : side-car pas démarré, mauvais port, ou mauvaise MODEL_URL
            _logger.LogError(ex, "Side-car injoignable sur {BaseAddress}", client.BaseAddress);
            return StatusCode(503, new { error = "Side-car injoignable", modelUrl = client.BaseAddress?.ToString() });
        }
    }

    // GET /health : santé du conteneur principal uniquement
    [HttpGet("/health")]
    public IActionResult Health() => Ok("ok");

    private record ModelAnswer(string Model, string Reply);
}
