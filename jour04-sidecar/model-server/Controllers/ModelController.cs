using Microsoft.AspNetCore.Mvc;

namespace ModelServer.Controllers;

public record GenerateRequest(string Prompt);

[ApiController]
public class ModelController : ControllerBase
{
    private readonly ILogger<ModelController> _logger;

    public ModelController(ILogger<ModelController> logger) => _logger = logger;

    // POST /generate  { "prompt": "..." }  ->  { "model": "...", "reply": "..." }
    // Simule un petit modèle de langage local (à la place de Phi-4, trop lourd pour un plan B1).
    [HttpPost("/generate")]
    public IActionResult Generate([FromBody] GenerateRequest request)
    {
        _logger.LogInformation("Side-car : prompt reçu ({Length} caractères)", request.Prompt.Length);

        var reply = $"[modèle factice] J'ai bien reçu : « {request.Prompt} »";
        return Ok(new { model = "fake-slm-v1", reply });
    }

    // GET /health : utilisé pour vérifier que le side-car a démarré
    [HttpGet("/health")]
    public IActionResult Health() => Ok("ok");
}
