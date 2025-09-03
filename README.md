# 🚀 Microsoft Kiota C# Client Generation Tutorial

> **Learn how to generate strongly-typed C# API clients from OpenAPI specifications using Microsoft Kiota**

[![.NET](https://img.shields.io/badge/.NET-9.0-512BD4)](https://dotnet.microsoft.com)
[![Kiota](https://img.shields.io/badge/Kiota-1.28.0-0078D4)](https://github.com/microsoft/kiota)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📚 Table of Contents

- [Introduction](#-introduction)
- [Why Kiota?](#-why-kiota)
- [The Schema Problem](#-the-schema-problem)
- [Quick Start](#-quick-start)
- [Prerequisites](#-prerequisites)
- [Step-by-Step Tutorial](#-step-by-step-tutorial)
- [Repository Structure](#-repository-structure)
- [Examples](#-examples)
- [Advanced Topics](#-advanced-topics)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

## 🎯 Introduction

This repository serves as a comprehensive tutorial for using **Microsoft Kiota** to generate C# API clients from OpenAPI specifications. You'll learn:

- ✅ How to generate strongly-typed API clients
- ✅ The importance of proper OpenAPI schemas
- ✅ How to handle both typed and untyped responses
- ✅ Integration with dependency injection
- ✅ Publishing to NuGet/Artifactory
- ✅ CI/CD automation with GitHub Actions

### What is Kiota?

[Kiota](https://github.com/microsoft/kiota) is Microsoft's modern OpenAPI-based code generator that creates strongly-typed API clients for multiple languages. Unlike traditional generators, Kiota focuses on:

- **Type safety**: Full IntelliSense and compile-time checking
- **Minimal dependencies**: Lightweight runtime libraries
- **Modern patterns**: Async/await, dependency injection, fluent APIs
- **Cross-platform**: Works on Windows, macOS, and Linux

## 🤔 Why Kiota?

### Traditional Approach Problems
- Writing API clients manually is time-consuming and error-prone
- Maintaining sync between API and client is challenging
- Different APIs require learning different client libraries
- No compile-time type safety for API responses

### Kiota Solution
- **Automatic generation** from OpenAPI specs
- **Strongly-typed models** (when schemas are properly defined)
- **Consistent API** across all generated clients
- **Built-in features**: Retry logic, authentication, serialization
- **Maintenance-free**: Just regenerate when API changes

## ⚠️ The Schema Problem

**Critical Learning Point:** The quality of your generated client depends entirely on your OpenAPI specification!

### ❌ Bad Schema (Generates UntypedNode)
```json
{
  "responses": {
    "200": {
      "description": "Success",
      "content": {
        "application/json": {
          "schema": {}  // Empty schema = No typing!
        }
      }
    }
  }
}
```

### ✅ Good Schema (Generates Typed Models)
```json
{
  "responses": {
    "200": {
      "description": "Success",
      "content": {
        "application/json": {
          "schema": {
            "$ref": "#/components/schemas/SearchResponse"
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "SearchResponse": {
        "type": "object",
        "properties": {
          "results": {
            "type": "array",
            "items": { "$ref": "#/components/schemas/Book" }
          }
        }
      }
    }
  }
}
```

## 🚀 Quick Start

Get up and running in 5 minutes:

```bash
# 1. Install Kiota
dotnet tool install -g Microsoft.OpenApi.Kiota

# 2. Clone this repository
git clone https://github.com/yourusername/kiota-tutorial.git
cd kiota-tutorial

# 3. Generate a typed client
kiota generate \
  --language CSharp \
  --openapi demo/openlibrary-enhanced.json \
  --output src/Generated \
  --namespace MyApi.Client

# 4. Build and run the demo
dotnet build
dotnet run --project demo/TestClient
```

## 📋 Prerequisites

- [.NET SDK 9.0+](https://dotnet.microsoft.com/download)
- [Kiota CLI](https://github.com/microsoft/kiota)
- Text editor (VS Code, Visual Studio, Rider)
- Basic knowledge of C# and REST APIs

## 📖 Step-by-Step Tutorial

### Step 1: Install Kiota

```bash
# Install globally
dotnet tool install -g Microsoft.OpenApi.Kiota

# Verify installation
kiota --version
```

### Step 2: Understand the OpenAPI Specs

This tutorial includes two OpenAPI specifications:

1. **`demo/openlibrary-openapi.json`** - Original spec with empty schemas (generates UntypedNode)
2. **`demo/openlibrary-enhanced.json`** - Enhanced spec with proper schemas (generates typed models)

Let's compare them:

```bash
# Generate client from original spec (untyped)
kiota generate \
  --language CSharp \
  --openapi demo/openlibrary-openapi.json \
  --output src/UntypedClient \
  --namespace OpenApi.Untyped

# Generate client from enhanced spec (typed)
kiota generate \
  --language CSharp \
  --openapi demo/openlibrary-enhanced.json \
  --output src/TypedClient \
  --namespace OpenApi.Typed
```

### Step 3: Compare Generated Code

#### Untyped Response (from original spec)
```csharp
// Returns UntypedNode - no compile-time type safety
var response = await client.SearchJson.GetAsync(config => 
{
    config.QueryParameters.Q = "Harry Potter";
});

// Must handle as generic object at runtime
if (response != null)
{
    // No IntelliSense, no type safety
    var obj = response.GetObject();
    // Manual parsing required...
}
```

#### Typed Response (from enhanced spec)
```csharp
// Returns SearchResponse - full type safety!
var response = await client.Search.GetAsync(config => 
{
    config.QueryParameters.Q = "Harry Potter";
});

if (response != null)
{
    // Full IntelliSense and compile-time checking
    Console.WriteLine($"Found {response.NumFound} results");
    foreach (var doc in response.Docs)
    {
        Console.WriteLine($"- {doc.Title} by {string.Join(", ", doc.AuthorName)}");
    }
}
```

### Step 4: Create Your Client Project

```xml
<!-- OpenApiClient.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  
  <ItemGroup>
    <PackageReference Include="Microsoft.Kiota.Bundle" Version="1.*" />
  </ItemGroup>
</Project>
```

### Step 5: Use the Client

```csharp
using Microsoft.Kiota.Abstractions.Authentication;
using Microsoft.Kiota.Http.HttpClientLibrary;
using OpenApi.Typed;

// Create client
var auth = new AnonymousAuthenticationProvider();
var adapter = new HttpClientRequestAdapter(auth);
var client = new OpenApiClientTyped(adapter);

// Make typed API calls
var searchResults = await client.Search.GetAsync(config =>
{
    config.QueryParameters.Q = "The Lord of the Rings";
    config.QueryParameters.Limit = 10;
});

// Work with strongly-typed results
foreach (var book in searchResults.Docs)
{
    Console.WriteLine($"{book.Title} ({book.FirstPublishYear})");
}
```

### Step 6: Dependency Injection

```csharp
// Program.cs
builder.Services.AddSingleton<IAuthenticationProvider, AnonymousAuthenticationProvider>();
builder.Services.AddHttpClient<IRequestAdapter, HttpClientRequestAdapter>();
builder.Services.AddTransient<OpenApiClientTyped>();

// In your service
public class BookService
{
    private readonly OpenApiClientTyped _client;
    
    public BookService(OpenApiClientTyped client)
    {
        _client = client;
    }
    
    public async Task<SearchResponse> SearchBooksAsync(string query)
    {
        return await _client.Search.GetAsync(config =>
        {
            config.QueryParameters.Q = query;
        });
    }
}
```

## 📁 Repository Structure

```
kiota-tutorial/
├── README.md                          # This tutorial
├── demo/
│   ├── openlibrary-openapi.json     # Original spec (empty schemas)
│   ├── openlibrary-enhanced.json    # Enhanced spec (typed schemas)
│   └── TestClient/                  # Demo console application
├── src/
│   ├── OpenApiClient/                # Main client library
│   │   ├── Generated/                # Untyped client (from original)
│   │   ├── GeneratedTyped/           # Typed client (from enhanced)
│   │   └── Extensions/               # DI extensions
│   └── OpenApiClient.csproj
├── test/
│   └── OpenApiClient.Tests/          # Unit tests
├── scripts/
│   ├── generate-and-publish.ps1     # PowerShell automation
│   └── generate-and-publish.sh      # Bash automation
└── .github/
    └── workflows/
        └── publish-client.yml        # CI/CD pipeline
```

## 🎓 Examples

### Example 1: Working with Typed Responses

```csharp
// Full type safety with enhanced schema
var author = await client.Authors["OL26320A"].GetAsync();

Console.WriteLine($"Author: {author.Name}");
Console.WriteLine($"Born: {author.BirthDate}");
Console.WriteLine($"Bio: {author.Bio?.Value}");

// Compile-time error if you try to access non-existent property
// author.NonExistentProperty // ❌ Compiler error!
```

### Example 2: Handling Untyped Responses

```csharp
// When schema is empty, you get UntypedNode
var response = await client.Books["OL27448W"].GetAsync();

// Must handle dynamically at runtime
if (response is UntypedObject obj)
{
    // No compile-time checking
    var title = obj.GetValue<string>("title");
    // Risk of runtime errors if property doesn't exist
}
```

### Example 3: Error Handling

```csharp
try
{
    var book = await client.Isbn["invalid-isbn"].GetAsync();
}
catch (ApiException ex) when (ex.ResponseStatusCode == 404)
{
    Console.WriteLine("Book not found");
}
catch (ApiException ex)
{
    Console.WriteLine($"API error: {ex.Message}");
}
```

## 🔧 Advanced Topics

### Custom Authentication

```csharp
public class CustomAuthProvider : IAuthenticationProvider
{
    public async Task AuthenticateRequestAsync(
        RequestInformation request,
        Dictionary<string, object>? additional = null,
        CancellationToken cancellation = default)
    {
        request.Headers.Add("X-API-Key", new[] { "your-api-key" });
    }
}
```

### Request Middleware

```csharp
var handlers = KiotaClientFactory.ChainHandlersCollectionAndGetFirstLink(
    KiotaClientFactory.GetDefaultHandlers(),
    new RetryHandler(),
    new RedirectHandler(),
    new LoggingHandler()
);

var httpClient = KiotaClientFactory.GetHttpClient(handlers);
```

### Publishing to NuGet/Artifactory

```bash
# Using provided script
./scripts/generate-and-publish.sh \
  --spec-url https://api.example.com/openapi.json \
  --version 1.0.0 \
  --artifactory-url https://artifactory.company.com
```

## 🐛 Troubleshooting

### Common Issues

#### 1. "UntypedNode has no GetObject() method"
- **Cause**: Using older Kiota version
- **Solution**: Update to latest: `dotnet tool update -g Microsoft.OpenApi.Kiota`

#### 2. All responses are UntypedNode
- **Cause**: OpenAPI spec has empty schemas
- **Solution**: Add proper schema definitions to your OpenAPI spec

#### 3. "Cannot find type OpenApiClient"
- **Cause**: Client not generated or wrong namespace
- **Solution**: Check output path and namespace in generation command

#### 4. Build errors after generation
- **Cause**: Missing NuGet packages
- **Solution**: Install `Microsoft.Kiota.Bundle` package

### Debug Tips

```bash
# Verbose logging during generation
kiota generate --log-level Debug ...

# Check what will be generated
kiota show --openapi your-spec.json

# Validate OpenAPI spec
kiota validate --openapi your-spec.json
```

## 🌟 Best Practices

1. **Always define schemas** in your OpenAPI spec
2. **Use `$ref`** to avoid duplication
3. **Version your API** and regenerate clients on changes
4. **Commit generated code** for easier debugging
5. **Use CI/CD** to automate client generation
6. **Test with real API** before publishing

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### How to Contribute

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📚 Additional Resources

- [Kiota Documentation](https://learn.microsoft.com/en-us/openapi/kiota/)
- [OpenAPI Specification](https://swagger.io/specification/)
- [Demo Branch](../../tree/demo) - Complete working example
- [Video Tutorial](https://youtube.com/...) - Coming soon!

## 📝 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Microsoft Kiota team for the excellent tool
- OpenLibrary for providing a public API
- Community contributors

---

**Ready to generate your first client?** Check out the [demo branch](../../tree/demo) for a complete working example, or start with the [Quick Start](#-quick-start) guide above!

For questions or issues, please [open an issue](../../issues) on GitHub.