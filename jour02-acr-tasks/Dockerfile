# =====================================================================
# Stage 1 : build (SDK) - restaure et compile l'app ET les tests
# =====================================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copie des .csproj seuls d'abord : le restore est mis en cache tant qu'ils ne changent pas
COPY app/MonApp.csproj app/
COPY tests/MonApp.Tests/MonApp.Tests.csproj tests/MonApp.Tests/
RUN dotnet restore tests/MonApp.Tests/MonApp.Tests.csproj

# Puis tout le code source
COPY . .
RUN dotnet build tests/MonApp.Tests/MonApp.Tests.csproj -c Release --no-restore
RUN dotnet publish app/MonApp.csproj -c Release -o /app/publish --no-restore

# =====================================================================
# Stage 2 : test - image qui, quand on la LANCE, exécute les tests
#   Construite avec : --target test
#   Code de sortie 0 = tests OK, différent de 0 = au moins un test KO
# =====================================================================
FROM build AS test
ENTRYPOINT ["dotnet", "test", "/src/tests/MonApp.Tests/MonApp.Tests.csproj", "-c", "Release", "--no-build"]

# =====================================================================
# Stage 3 : final (runtime ASP.NET, sans SDK ni tests) - l'image publiée
# =====================================================================
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

ENV ASPNETCORE_HTTP_PORTS=8000 \
    APP_MESSAGE="Bonjour depuis ACR Tasks" \
    APP_VERSION="jour2-trigger"
# DB_PASSWORD n'est volontairement PAS ici : injecté à l'exécution.

EXPOSE 8000
COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "MonApp.dll"]
