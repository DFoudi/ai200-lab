# ---------- Étape 1 : build (image SDK) ----------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ModelServer.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# ---------- Étape 2 : runtime (image ASP.NET) ----------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# Side-car : port INTERNE 5000 (chaque conteneur de l'application web doit avoir un port différent).
# Le port est gravé dans l'image et NON dans un App Setting : les App Settings sont
# partagés par TOUS les conteneurs de l'application web (principal + side-cars).
ENV ASPNETCORE_HTTP_PORTS=5000
EXPOSE 5000

COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "ModelServer.dll"]
