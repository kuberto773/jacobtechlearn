using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http.Extensions;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Store WebSocket clients
var webSockets = new List<WebSocket>();

// Middleware to handle WebSocket connections at /ws
app.Map("/ws", async context =>
{
    if (context.WebSockets.IsWebSocketRequest)
    {
        using var ws = await context.WebSockets.AcceptWebSocketAsync();
        webSockets.Add(ws);

        var buffer = new byte[1024 * 4];
        while (ws.State == WebSocketState.Open)
        {
            var result = await ws.ReceiveAsync(buffer, context.RequestAborted);
            if (result.MessageType == WebSocketMessageType.Close)
            {
                await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "Closing", context.RequestAborted);
                webSockets.Remove(ws);
            }
        }
    }
    else
    {
        context.Response.StatusCode = 400;
    }
});

// Serve main HTML page
app.MapGet("/", () =>
{
    var html = """
    <html>
    <body>
        <h2>Incoming Requests</h2>
        <ul id="requests"></ul>

        <script>
            const ul = document.getElementById("requests");
            const ws = new WebSocket(`wss://${location.host}/ws`);

            ws.onmessage = function(event) {
                const req = JSON.parse(event.data);
                const li = document.createElement("li");
                li.innerHTML = `<b>${req.Method}</b> ${req.Url} at ${req.Timestamp}`;
                ul.appendChild(li);
            };
        </script>
    </body>
    </html>
    """;

    return Results.Content(html, "text/html");
});

// Broadcast helper
async Task BroadcastRequest(RequestInfo req)
{
    var json = JsonSerializer.Serialize(req);
    var buffer = Encoding.UTF8.GetBytes(json);

    foreach (var ws in webSockets.ToArray())
    {
        if (ws.State == WebSocketState.Open)
        {
            await ws.SendAsync(buffer, WebSocketMessageType.Text, true, CancellationToken.None);
        }
        else
        {
            webSockets.Remove(ws);
        }
    }
}

// Endpoints
app.MapGet("/test", async (HttpRequest request) =>
{
    var info = new RequestInfo(request.Method, request.GetDisplayUrl(), DateTime.Now);
    await BroadcastRequest(info);
    return Results.Ok(new { message = "GET request received" });
});

app.MapPost("/test", async (HttpRequest request) =>
{
    var info = new RequestInfo(request.Method, request.GetDisplayUrl(), DateTime.Now);
    await BroadcastRequest(info);
    return Results.Ok(new { message = "POST request received" });
});

app.MapPut("/test", async (HttpRequest request) =>
{
    var info = new RequestInfo(request.Method, request.GetDisplayUrl(), DateTime.Now);
    await BroadcastRequest(info);
    return Results.Ok(new { message = "PUT request received" });
});

// Enable WebSockets
var wsOptions = new WebSocketOptions { KeepAliveInterval = TimeSpan.FromSeconds(30) };
app.UseWebSockets(wsOptions);

app.Run();

record RequestInfo(string Method, string Url, DateTime Timestamp);
