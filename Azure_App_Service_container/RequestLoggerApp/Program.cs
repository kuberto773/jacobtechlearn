using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Http.Extensions;
using System.Text.Json;

// Build the web app
var builder = WebApplication.CreateBuilder(args);

// Configure JSON to use camelCase
builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
});

// Add SignalR
builder.Services.AddSignalR(); // Remove .AddAzureSignalR() unless you provide connection string

var app = builder.Build();

// Serve HTML client
app.MapGet("/", () =>
{
    var html = """
    <html>
    <body>
        <h2>Incoming Requests</h2>
        <ul id="requests"></ul>

        <script src="https://cdnjs.cloudflare.com/ajax/libs/microsoft-signalr/7.0.5/signalr.min.js"></script>
        <script>
            const ul = document.getElementById("requests");

            const connection = new signalR.HubConnectionBuilder()
                .withUrl("/requestHub")
                .withAutomaticReconnect([0, 2000, 10000, 30000])
                .build();

            connection.on("ReceiveRequest", req => {
                const li = document.createElement("li");
                li.innerHTML = `<b>${req.method}</b> ${req.url} at ${req.timestamp}`;
                ul.appendChild(li);
            });

            async function start() {
                try {
                    await connection.start();
                    console.log("SignalR connected!");
                } catch (err) {
                    console.error("SignalR connection error:", err);
                    setTimeout(start, 5000);
                }
            }

            connection.onclose(() => start());
            start();
        </script>
    </body>
    </html>
    """;

    return Results.Content(html, "text/html");
});

// Async broadcast helper
async Task BroadcastRequestAsync(RequestInfo req)
{
    var hubContext = app.Services.GetRequiredService<IHubContext<RequestHub>>();
    await hubContext.Clients.All.SendAsync("ReceiveRequest", req);
}

// Endpoints
app.MapGet("/test", async (HttpRequest request) =>
{
    var info = new RequestInfo(request.Method, request.GetDisplayUrl(), DateTime.UtcNow);
    await BroadcastRequestAsync(info);
    return Results.Ok(new { message = "GET request received" });
});

app.MapPost("/test", async (HttpRequest request) =>
{
    var info = new RequestInfo(request.Method, request.GetDisplayUrl(), DateTime.UtcNow);
    await BroadcastRequestAsync(info);
    return Results.Ok(new { message = "POST request received" });
});

app.MapPut("/test", async (HttpRequest request) =>
{
    var info = new RequestInfo(request.Method, request.GetDisplayUrl(), DateTime.UtcNow);
    await BroadcastRequestAsync(info);
    return Results.Ok(new { message = "PUT request received" });
});

// Map SignalR hub
app.MapHub<RequestHub>("/requestHub");

app.Run();

// Record to hold request info
record RequestInfo(string Method, string Url, DateTime Timestamp);
