var builder = WebApplication.CreateBuilder(args);
builder.Logging.AddJsonConsole();

var app = builder.Build();
var requestCounts = new System.Collections.Concurrent.ConcurrentDictionary<string, long>();
void Record(string status) => requestCounts.AddOrUpdate(status, 1, (_, count) => count + 1);

app.Use(async (context, next) =>
{
    var startedAt = DateTimeOffset.UtcNow;
    await next();
    if (context.Request.Path != "/metrics" && context.Request.Path != "/healthz")
    {
        var durationMs = (DateTimeOffset.UtcNow - startedAt).TotalMilliseconds;
        Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(new
        {
            @event = "http_request",
            service = "${{ values.componentId }}",
            path = context.Request.Path.Value,
            status = context.Response.StatusCode,
            duration_ms = durationMs,
        }));
    }
});

app.MapGet("/healthz", () =>
{
    return Results.Ok(new { status = "ok" });
});
app.MapGet("/metrics", () =>
{
    var lines = new List<string>
    {
        "# HELP http_server_requests_total Total HTTP requests by status code.",
        "# TYPE http_server_requests_total counter",
    };
    lines.AddRange(requestCounts.Select(entry => $"http_server_requests_total{{service=\"${{ values.componentId }}\",status=\"{entry.Key}\"}} {entry.Value}"));
    return Results.Text(string.Join("\n", lines) + "\n", "text/plain; version=0.0.4");
});
app.MapGet("/", () =>
{
    Record("200");
    return new { service = "${{ values.componentId }}", team = "${{ values.teamName }}" };
});
app.Run();
