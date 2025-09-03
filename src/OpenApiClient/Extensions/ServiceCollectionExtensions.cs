using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Kiota.Abstractions;
using Microsoft.Kiota.Abstractions.Authentication;
using Microsoft.Kiota.Abstractions.Serialization;
using Microsoft.Kiota.Http.HttpClientLibrary;
using Microsoft.Kiota.Serialization.Json;
using Microsoft.Kiota.Serialization.Text;
using Microsoft.Kiota.Serialization.Form;
using Microsoft.Kiota.Serialization.Multipart;
using System;
using System.Collections.Generic;
using System.Net.Http;

namespace OpenApiClient.Extensions
{
    /// <summary>
    /// Extension methods for configuring the OpenAPI client with dependency injection
    /// </summary>
    public static class ServiceCollectionExtensions
    {
        /// <summary>
        /// Adds the Kiota-generated API client to the service collection
        /// </summary>
        /// <param name="services">The service collection</param>
        /// <param name="configuration">The configuration</param>
        /// <returns>The service collection for chaining</returns>
        public static IServiceCollection AddOpenApiClient(
            this IServiceCollection services,
            IConfiguration configuration)
        {
            var settings = configuration.GetSection("OpenApi")
                .Get<OpenApiClientSettings>() ?? new OpenApiClientSettings();
            
            return services.AddOpenApiClient(settings);
        }

        /// <summary>
        /// Adds the Kiota-generated API client with custom settings
        /// </summary>
        /// <param name="services">The service collection</param>
        /// <param name="configureSettings">Action to configure settings</param>
        /// <returns>The service collection for chaining</returns>
        public static IServiceCollection AddOpenApiClient(
            this IServiceCollection services,
            Action<OpenApiClientSettings> configureSettings)
        {
            var settings = new OpenApiClientSettings();
            configureSettings(settings);
            return services.AddOpenApiClient(settings);
        }

        /// <summary>
        /// Adds the Kiota-generated API client with settings
        /// </summary>
        /// <param name="services">The service collection</param>
        /// <param name="settings">The client settings</param>
        /// <returns>The service collection for chaining</returns>
        public static IServiceCollection AddOpenApiClient(
            this IServiceCollection services,
            OpenApiClientSettings settings)
        {
            // Register settings
            services.AddSingleton(settings);

            // Register Kiota serialization factories
            services.AddSingleton<ISerializationWriterFactory>(sp => new JsonSerializationWriterFactory());
            services.AddSingleton<IParseNodeFactory>(sp => new JsonParseNodeFactory());

            // Register authentication provider
            services.AddSingleton<IAuthenticationProvider>(sp =>
            {
                if (!string.IsNullOrEmpty(settings.ApiKey))
                {
                    return new Microsoft.Kiota.Abstractions.Authentication.ApiKeyAuthenticationProvider(
                        settings.ApiKey,
                        settings.ApiKeyHeader ?? "X-API-Key",
                        Microsoft.Kiota.Abstractions.Authentication.ApiKeyAuthenticationProvider.KeyLocation.Header);
                }
                else if (!string.IsNullOrEmpty(settings.BearerToken))
                {
                    return new BaseBearerTokenAuthenticationProvider(
                        new StaticAccessTokenProvider(settings.BearerToken));
                }
                else
                {
                    return new AnonymousAuthenticationProvider();
                }
            });

            // Register HttpClient with appropriate configuration
            services.AddHttpClient("OpenApiClient", (httpClient) =>
            {
                httpClient.BaseAddress = new Uri(settings.BaseUrl);
                httpClient.Timeout = TimeSpan.FromSeconds(settings.TimeoutSeconds);
                
                // Add custom headers if specified
                if (settings.CustomHeaders != null)
                {
                    foreach (var header in settings.CustomHeaders)
                    {
                        httpClient.DefaultRequestHeaders.Add(header.Key, header.Value);
                    }
                }
            });

            // Register the request adapter
            services.AddTransient<IRequestAdapter>(serviceProvider =>
            {
                var httpClientFactory = serviceProvider.GetRequiredService<IHttpClientFactory>();
                var httpClient = httpClientFactory.CreateClient("OpenApiClient");
                var authProvider = serviceProvider.GetRequiredService<IAuthenticationProvider>();
                
                return new HttpClientRequestAdapter(authProvider, httpClient: httpClient);
            });

            // Register the API client (will be generated by Kiota)
            services.AddTransient<OpenApiClient>(serviceProvider =>
            {
                var requestAdapter = serviceProvider.GetRequiredService<IRequestAdapter>();
                return new OpenApiClient(requestAdapter);
            });

            return services;
        }
    }

    /// <summary>
    /// Settings for configuring the OpenAPI client
    /// </summary>
    public class OpenApiClientSettings
    {
        /// <summary>
        /// The base URL for the API
        /// </summary>
        public string BaseUrl { get; set; } = "https://openlibrary.org";

        /// <summary>
        /// API key for authentication (if required)
        /// </summary>
        public string? ApiKey { get; set; }

        /// <summary>
        /// The header name for the API key
        /// </summary>
        public string? ApiKeyHeader { get; set; } = "X-API-Key";

        /// <summary>
        /// Bearer token for authentication (if required)
        /// </summary>
        public string? BearerToken { get; set; }

        /// <summary>
        /// Request timeout in seconds
        /// </summary>
        public int TimeoutSeconds { get; set; } = 30;

        /// <summary>
        /// Maximum number of retries for failed requests
        /// </summary>
        public int MaxRetries { get; set; } = 3;

        /// <summary>
        /// Custom headers to add to all requests
        /// </summary>
        public Dictionary<string, string>? CustomHeaders { get; set; }
    }


    /// <summary>
    /// Simple static access token provider
    /// </summary>
    public class StaticAccessTokenProvider : IAccessTokenProvider
    {
        private readonly string _token;

        public StaticAccessTokenProvider(string token)
        {
            _token = token ?? throw new ArgumentNullException(nameof(token));
        }

        public Task<string> GetAuthorizationTokenAsync(
            Uri uri,
            Dictionary<string, object>? additionalAuthenticationContext = null,
            CancellationToken cancellationToken = default)
        {
            return Task.FromResult(_token);
        }

        public AllowedHostsValidator AllowedHostsValidator { get; } = new AllowedHostsValidator();
    }
}