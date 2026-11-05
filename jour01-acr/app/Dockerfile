# ---------- Étape 1 : build (image SDK, lourde) ----------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# On copie d'abord le .csproj seul pour profiter du cache de couche sur le restore
COPY MonApp.csproj .
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# ---------- Étape 2 : runtime (image ASP.NET, légère) ----------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# Port d'écoute de Kestrel (par défaut 8080 dans les images .NET 8+)
ENV ASPNETCORE_HTTP_PORTS=8000 \
    APP_MESSAGE="Bonjour depuis ACR" \
    APP_VERSION="v2"
# DB_PASSWORD n'est volontairement PAS ici : un secret ne doit jamais être gravé dans une image.

EXPOSE 8000

COPY --from=build /app/publish .

# Utilisateur non-root fourni par les images .NET officielles
USER $APP_UID

ENTRYPOINT ["dotnet", "MonApp.dll"]
