using Microsoft.AspNetCore.Mvc;

namespace MonApp.Controllers;

[ApiController]
public class InfoController : ControllerBase
{
    // GET /
    // Doit renvoyer APP_MESSAGE et APP_VERSION (avec une valeur par défaut si absentes).
    // Exemple attendu : { "message": "Bonjour depuis ACR", "version": "v1" }
    [HttpGet("/")]
    public IActionResult GetInfo()
    {
        // TODO 1 : lire les variables d'environnement APP_MESSAGE et APP_VERSION
        // TODO 2 : prévoir une valeur par défaut si elles sont absentes
        // TODO 3 : renvoyer un objet JSON (200 OK)
                // 1. On lit la variable d'environnement APP_MESSAGE
        string message = Environment.GetEnvironmentVariable("APP_MESSAGE");

        // 2. Si elle n'existe pas, la méthode renvoie null : on met un texte par défaut
        if (message == null)
        {
            message = "Message par défaut";
        }

        // 3. Pareil pour APP_VERSION
        string version = Environment.GetEnvironmentVariable("APP_VERSION");
        if (version == null)
        {
            version = "inconnue";
        }

        // 4. On renvoie la réponse HTTP 200 avec ces deux valeurs
        return Ok(new { message = message, version = version });
    }

    // GET /secret
    // Doit renvoyer UNIQUEMENT les 3 premiers caractères de DB_PASSWORD.
    // Exemple attendu : { "secretPreview": "abc***" }
    [HttpGet("/secret")]
    public IActionResult GetSecret()
    {
        // TODO 4 : lire DB_PASSWORD
        // TODO 5 : gérer le cas où elle est absente OU fait moins de 3 caractères
        // TODO 6 : ne renvoyer que les 3 premiers caractères (jamais le secret complet !)
        // 1. On lit le secret, exactement comme APP_MESSAGE
        string password = Environment.GetEnvironmentVariable("DB_PASSWORD");

        // 2. S'il n'existe pas, on le dit (sans planter)
        if (password == null)
        {
            return Ok(new { secretPreview = "non défini" });
        }

        // 3. S'il est trop court, on ne peut pas prendre 3 caractères
        if (password.Length < 3)
        {
            return Ok(new { secretPreview = "trop court" });
        }

        // 4. On ne garde que les 3 premiers caractères, puis on masque le reste
        string debut = password.Substring(0, 3);
        return Ok(new { secretPreview = debut + "***" });
    }

    // GET /health
    // Doit renvoyer { "status": "ok" } -> servira de sonde (probe) dans Container Apps
    [HttpGet("/health")]
    public IActionResult GetHealth()
    {
        // TODO 7 : renvoyer { "status": "ok" }
                return Ok(new { status = "ok" });
    }
}
