using Microsoft.Extensions.DependencyInjection;
using Microsoft.Kiota.Abstractions.Authentication;
using Microsoft.Kiota.Abstractions.Serialization;
using Microsoft.Kiota.Http.HttpClientLibrary;
using OpenApiClient;
using OpenApiClient.Extensions;
using System;
using System.Linq;
using System.Threading.Tasks;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("========================================");
        Console.WriteLine("OpenLibrary API Client Test");
        Console.WriteLine("Generated with Microsoft Kiota");
        Console.WriteLine("========================================\n");

        try
        {
            await TestDirectClient();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\nError: {ex.Message}");
            if (ex.InnerException != null)
            {
                Console.WriteLine($"Inner: {ex.InnerException.Message}");
            }
        }
    }

    static async Task TestDirectClient()
    {
        Console.WriteLine("Testing Generated OpenAPI Client");
        Console.WriteLine("=================================\n");

        // OpenLibrary doesn't require authentication, so we use AnonymousAuthenticationProvider
        var authProvider = new AnonymousAuthenticationProvider();
        
        // Create HTTP client with base URL
        var httpClient = new HttpClient
        {
            BaseAddress = new Uri("https://openlibrary.org"),
            Timeout = TimeSpan.FromSeconds(30)
        };
        httpClient.DefaultRequestHeaders.Add("User-Agent", "OpenApiClient-Test/1.0");
        
        // Create request adapter
        var requestAdapter = new HttpClientRequestAdapter(authProvider, httpClient: httpClient);
        
        // Create the API client
        var client = new OpenApiClient.OpenApiClient(requestAdapter);
        
        // Test 1: Search for books using search.json endpoint
        Console.WriteLine("1. Searching for 'The Lord of the Rings'...");
        try
        {
            var searchResult = await client.SearchJson.GetAsync(requestConfiguration =>
            {
                requestConfiguration.QueryParameters.Q = "The Lord of the Rings";
                requestConfiguration.QueryParameters.Page = 1;
            });
            
            if (searchResult != null)
            {
                Console.WriteLine("   ✓ Search request successful!");
                Console.WriteLine("   Response type: " + searchResult.GetType().Name);
                
                // UntypedNode doesn't have direct access methods in newer versions
                // Just show that we got a response
                Console.WriteLine("   Received search results from OpenLibrary API");
            }
            else
            {
                Console.WriteLine("   ⚠ Received null response");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"   ✗ Search failed: {ex.Message}");
            if (ex.InnerException != null)
            {
                Console.WriteLine($"     Inner exception: {ex.InnerException.Message}");
            }
        }
        
        // Test 2: Get author information
        Console.WriteLine("\n2. Getting author information for J.R.R. Tolkien (OL26320A)...");
        try
        {
            var authorResult = await client.Authors["OL26320A"].GetAsync();
            
            if (authorResult != null)
            {
                Console.WriteLine("   ✓ Author request successful!");
                Console.WriteLine("   Response type: " + authorResult.GetType().Name);
                Console.WriteLine("   Received author information from OpenLibrary API");
            }
            else
            {
                Console.WriteLine("   ⚠ Received null response");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"   ✗ Author request failed: {ex.Message}");
            if (ex.InnerException != null)
            {
                Console.WriteLine($"     Inner exception: {ex.InnerException.Message}");
            }
        }
        
        // Test 3: Get book by ISBN
        Console.WriteLine("\n3. Getting book by ISBN (0395489318 - The Hobbit)...");
        try
        {
            var bookResult = await client.Isbn["0395489318"].GetAsync();
            
            if (bookResult != null)
            {
                Console.WriteLine("   ✓ ISBN request successful!");
                Console.WriteLine("   Response type: " + bookResult.GetType().Name);
                Console.WriteLine("   Received book information from OpenLibrary API");
            }
            else
            {
                Console.WriteLine("   ⚠ Received null response");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"   ✗ ISBN request failed: {ex.Message}");
            if (ex.InnerException != null)
            {
                Console.WriteLine($"     Inner exception: {ex.InnerException.Message}");
            }
        }
        
        // Test 4: Using Dependency Injection
        Console.WriteLine("\n4. Testing with Dependency Injection...");
        try
        {
            var services = new ServiceCollection();
            services.AddOpenApiClient(settings =>
            {
                settings.BaseUrl = "https://openlibrary.org";
                settings.TimeoutSeconds = 30;
            });
            
            var serviceProvider = services.BuildServiceProvider();
            var diClient = serviceProvider.GetService<OpenApiClient.OpenApiClient>();
            
            if (diClient != null)
            {
                Console.WriteLine("   ✓ Successfully resolved client from DI container");
                
                // Quick test with DI client
                var testResult = await diClient.SearchJson.GetAsync(config =>
                {
                    config.QueryParameters.Q = "Harry Potter";
                    config.QueryParameters.Page = 1;
                });
                
                if (testResult != null)
                {
                    Console.WriteLine("   ✓ DI client successfully made API call");
                }
            }
            else
            {
                Console.WriteLine("   ✗ Failed to resolve client from DI container");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"   ✗ DI test failed: {ex.Message}");
        }
        
        Console.WriteLine("\n========================================");
        Console.WriteLine("Test Complete!");
        Console.WriteLine("========================================");
    }
}