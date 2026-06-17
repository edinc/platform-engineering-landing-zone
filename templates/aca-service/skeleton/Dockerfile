{% if values.language == "node-ts" %}
FROM node:20.18-alpine AS runtime
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY src/node-ts ./src/node-ts
ENV PORT=${{ values.port }}
EXPOSE ${{ values.port }}
USER 1000
CMD ["node", "src/node-ts/server.js"]
{% elif values.language == "python" %}
FROM python:3.12-alpine AS runtime
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/python ./src/python
RUN addgroup -S app && adduser -S -G app -u 10001 app \
    && chown -R app:app /app
ENV PORT=${{ values.port }}
EXPOSE ${{ values.port }}
USER 10001
CMD ["python", "src/python/app.py"]
{% else %}
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src
COPY src/dotnet/${{ values.componentId }}.csproj ./app.csproj
RUN dotnet restore ./app.csproj
COPY src/dotnet .
RUN dotnet publish ./app.csproj -c Release -o /out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
COPY --from=build /out .
ENV ASPNETCORE_URLS=http://0.0.0.0:${{ values.port }}
EXPOSE ${{ values.port }}
USER 64198
CMD ["dotnet", "${{ values.componentId }}.dll"]
{% endif %}
