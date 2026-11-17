# ---------- Étape 1 : build (image SDK) ----------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ChatApi.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# ---------- Étape 2 : runtime (image ASP.NET) ----------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# Conteneur PRINCIPAL : en mode side-car, App Service n'accepte le trafic externe
# que sur le port 80 ou 8080 (WEBSITES_PORT n'est plus pris en compte).
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "ChatApi.dll"]
