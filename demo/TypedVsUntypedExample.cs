using Microsoft.Extensions.DependencyInjection;
using Microsoft.Kiota.Abstractions.Authentication;
using Microsoft.Kiota.Abstractions.Serialization;
using Microsoft.Kiota.Http.HttpClientLibrary;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace KiotaTutorial.Examples
{
    /// <summary>
    /// This example demonstrates the critical difference between typed and untyped API responses
    /// when using Microsoft Kiota for OpenAPI client generation.
    /// </summary>
    public class TypedVsUntypedExample
    {
        public static async Task Main(string[] args)
        {
            Console.WriteLine("==============================================");
            Console.WriteLine("Kiota: Typed vs Untyped Responses Demo");
            Console.WriteLine("==============================================\n");

            // Demo both approaches
            await DemonstrateUntypedResponse();
            Console.WriteLine("\n" + new string('-', 50) + "\n");
            await DemonstrateTypedResponse();
            
            Console.WriteLine("\n==============================================");
            Console.WriteLine("Key Takeaway: Always define proper schemas in");
            Console.WriteLine("your OpenAPI spec to get typed models!");
            Console.WriteLine("==============================================");
        }

        /// <summary>
        /// Demonstrates working with UNTYPED responses (from OpenAPI specs with empty schemas)
        /// </summary>
        static async Task DemonstrateUntypedResponse()
        {
            Console.WriteLine("❌ UNTYPED Response (Empty Schema in OpenAPI)");
            Console.WriteLine("================================================\n");

            // Setup client for original OpenAPI spec (with empty schemas)
            var auth = new AnonymousAuthenticationProvider();
            var httpClient = new HttpClient { BaseAddress = new Uri("https://openlibrary.org") };
            var adapter = new HttpClientRequestAdapter(auth, httpClient: httpClient);
            var untypedClient = new OpenApiClient.OpenApiClient(adapter);

            try
            {
                // This returns UntypedNode because the OpenAPI spec has empty schema
                Console.WriteLine("Calling API with empty schema definition...");
                var searchResult = await untypedClient.SearchJson.GetAsync(config =>
                {
                    config.QueryParameters.Q = "The Hobbit";
                    config.QueryParameters.Page = 1;
                });

                if (searchResult != null)
                {
                    Console.WriteLine($"✓ Received response of type: {searchResult.GetType().Name}");
                    Console.WriteLine();
                    Console.WriteLine("Problems with UntypedNode:");
                    Console.WriteLine("  • No IntelliSense support");
                    Console.WriteLine("  • No compile-time type checking");
                    Console.WriteLine("  • Risk of runtime errors");
                    Console.WriteLine("  • Manual parsing required");
                    Console.WriteLine("  • No property documentation");
                    
                    // Attempting to work with untyped data
                    if (searchResult is UntypedObject untypedObj)
                    {
                        Console.WriteLine("\nTrying to extract data manually:");
                        
                        // This is error-prone and has no compile-time safety
                        // You won't know if these properties exist until runtime!
                        
                        // Try to get numFound - might fail at runtime
                        if (untypedObj.TryGetValue("numFound", out var numFoundNode))
                        {
                            // Even getting a simple value requires checking types
                            if (numFoundNode is UntypedInteger numFoundInt)
                            {
                                Console.WriteLine($"  Found {numFoundInt.GetValue()} results (manually parsed)");
                            }
                        }
                        else
                        {
                            Console.WriteLine("  ⚠ Property 'numFound' not found!");
                        }
                        
                        // What if we typo the property name? Runtime error!
                        if (untypedObj.TryGetValue("numFond", out var typoNode)) // Typo!
                        {
                            Console.WriteLine("  This won't be found due to typo");
                        }
                        else
                        {
                            Console.WriteLine("  ⚠ Typos in property names only fail at runtime!");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        /// <summary>
        /// Demonstrates working with TYPED responses (from OpenAPI specs with proper schemas)
        /// </summary>
        static async Task DemonstrateTypedResponse()
        {
            Console.WriteLine("✅ TYPED Response (Proper Schema in OpenAPI)");
            Console.WriteLine("================================================\n");

            // Setup client for enhanced OpenAPI spec (with proper schemas)
            var auth = new AnonymousAuthenticationProvider();
            var httpClient = new HttpClient { BaseAddress = new Uri("https://openlibrary.org") };
            var adapter = new HttpClientRequestAdapter(auth, httpClient: httpClient);
            var typedClient = new OpenApiClient.Typed.OpenApiClientTyped(adapter);

            try
            {
                // This returns a strongly-typed SearchResponse object!
                Console.WriteLine("Calling API with proper schema definition...");
                var searchResult = await typedClient.SearchJson.GetAsync(config =>
                {
                    config.QueryParameters.Q = "The Hobbit";
                    config.QueryParameters.Limit = 5;
                });

                if (searchResult != null)
                {
                    Console.WriteLine($"✓ Received response of type: SearchResponse");
                    Console.WriteLine();
                    Console.WriteLine("Benefits of Typed Models:");
                    Console.WriteLine("  • Full IntelliSense support");
                    Console.WriteLine("  • Compile-time type checking");
                    Console.WriteLine("  • No runtime surprises");
                    Console.WriteLine("  • Auto-completion for properties");
                    Console.WriteLine("  • XML documentation from OpenAPI");
                    
                    Console.WriteLine("\nWorking with typed data:");
                    
                    // Direct property access with full type safety
                    Console.WriteLine($"  Found {searchResult.NumFound} results");
                    Console.WriteLine($"  Query: {searchResult.Q}");
                    
                    // Strongly-typed collections
                    if (searchResult.Docs != null && searchResult.Docs.Count > 0)
                    {
                        Console.WriteLine($"  Displaying first {Math.Min(3, searchResult.Docs.Count)} results:");
                        
                        foreach (var doc in searchResult.Docs.Take(3))
                        {
                            // All properties are typed and documented
                            Console.WriteLine($"    📚 {doc.Title}");
                            
                            // Null-safe navigation with proper types
                            if (doc.AuthorName != null && doc.AuthorName.Count > 0)
                            {
                                Console.WriteLine($"       by {string.Join(", ", doc.AuthorName)}");
                            }
                            
                            if (doc.FirstPublishYear != null)
                            {
                                Console.WriteLine($"       First published: {doc.FirstPublishYear}");
                            }
                        }
                    }
                    
                    // This would cause a compile error (property doesn't exist):
                    // searchResult.NonExistentProperty = "value"; // ❌ Compiler catches this!
                    
                    Console.WriteLine("\n  ✅ No manual parsing needed!");
                    Console.WriteLine("  ✅ Typos caught at compile time!");
                    Console.WriteLine("  ✅ Refactoring tools work perfectly!");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        /// <summary>
        /// Shows side-by-side comparison of the development experience
        /// </summary>
        public static void CompareDevelopmentExperience()
        {
            Console.WriteLine("\n📊 Development Experience Comparison");
            Console.WriteLine("=====================================\n");
            
            Console.WriteLine("Untyped (Empty Schema)           | Typed (Proper Schema)");
            Console.WriteLine("----------------------------------|----------------------------------");
            Console.WriteLine("❌ No IntelliSense               | ✅ Full IntelliSense");
            Console.WriteLine("❌ Runtime type checking         | ✅ Compile-time type checking");
            Console.WriteLine("❌ Manual parsing                | ✅ Direct property access");
            Console.WriteLine("❌ String-based property access  | ✅ Strongly-typed properties");
            Console.WriteLine("❌ No refactoring support        | ✅ Full refactoring support");
            Console.WriteLine("❌ Runtime errors from typos     | ✅ Compile-time error detection");
            Console.WriteLine("❌ No property documentation     | ✅ XML docs from OpenAPI");
            Console.WriteLine("❌ Complex error handling        | ✅ Simple try-catch");
            Console.WriteLine("❌ Difficult to maintain         | ✅ Easy to maintain");
            Console.WriteLine("❌ Poor debugging experience     | ✅ Excellent debugging");
        }
    }

    /// <summary>
    /// Example of how to fix an OpenAPI spec to get typed models
    /// </summary>
    public static class OpenApiSchemaFix
    {
        public const string BadSchema = @"
        {
          'responses': {
            '200': {
              'description': 'Success',
              'content': {
                'application/json': {
                  'schema': {}  // ❌ EMPTY SCHEMA = UNTYPED!
                }
              }
            }
          }
        }";

        public const string GoodSchema = @"
        {
          'responses': {
            '200': {
              'description': 'Success',
              'content': {
                'application/json': {
                  'schema': {
                    '$ref': '#/components/schemas/SearchResponse'  // ✅ PROPER SCHEMA = TYPED!
                  }
                }
              }
            }
          },
          'components': {
            'schemas': {
              'SearchResponse': {
                'type': 'object',
                'properties': {
                  'numFound': { 'type': 'integer' },
                  'docs': {
                    'type': 'array',
                    'items': { '$ref': '#/components/schemas/SearchDoc' }
                  }
                }
              },
              'SearchDoc': {
                'type': 'object',
                'properties': {
                  'title': { 'type': 'string' },
                  'author_name': {
                    'type': 'array',
                    'items': { 'type': 'string' }
                  }
                }
              }
            }
          }
        }";
    }
}