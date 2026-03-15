package com.plantmanager.health;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.HealthCheckResponseBuilder;
import org.eclipse.microprofile.health.Readiness;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Optional;

/**
 * Trefle.io API readiness health check.
 * Verifies that the external plant API is reachable.
 * Used by Kubernetes readiness probe at /q/health/ready
 * 
 * Note: This check is lenient - if Trefle is down, we still serve traffic
 * using cached data. The check reports status but doesn't fail the probe.
 */
@Readiness
@ApplicationScoped
public class TrefleApiHealthCheck implements HealthCheck {

    private static final String CHECK_NAME = "trefle-api";
    private static final String TREFLE_HEALTH_URL = "https://trefle.io/api/v1/plants";
    private static final String STATUS_DEGRADED = "degraded";
    private static final String KEY_STATUS = "status";
    private static final String KEY_REASON = "reason";
    private static final String KEY_RESPONSE_CODE = "responseCode";

    @ConfigProperty(name = "trefle.api.token")
    Optional<String> trefleToken;

    private final HttpClient httpClient;

    public TrefleApiHealthCheck() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();
        // trefleToken is injected by CDI at runtime; initialize for direct instantiation in tests
        this.trefleToken = Optional.empty();
    }

    /** Package-private constructor for unit testing with a mock HttpClient. */
    TrefleApiHealthCheck(HttpClient httpClient) {
        this.httpClient = httpClient;
        this.trefleToken = Optional.empty();
    }

    @Override
    public HealthCheckResponse call() {
        HealthCheckResponseBuilder builder = HealthCheckResponse.named(CHECK_NAME);

        // If no token configured, report as degraded but UP (we use cache)
        String token = trefleToken.orElse("");
        if (token.isBlank() || "not-configured".equals(token)) {
            return builder
                    .up()
                    .withData(KEY_STATUS, STATUS_DEGRADED)
                    .withData(KEY_REASON, "No API token configured - using cache only")
                    .build();
        }

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(TREFLE_HEALTH_URL + "?token=" + token + "&page_size=1"))
                    .timeout(Duration.ofSeconds(5))
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            int statusCode = response.statusCode();

            if (statusCode >= 200 && statusCode < 300) {
                return builder
                        .up()
                        .withData(KEY_STATUS, "available")
                        .withData(KEY_RESPONSE_CODE, statusCode)
                        .build();
            } else if (statusCode == 401 || statusCode == 403) {
                return builder
                        .up()
                        .withData(KEY_STATUS, STATUS_DEGRADED)
                        .withData(KEY_REASON, "Invalid API token")
                        .withData(KEY_RESPONSE_CODE, statusCode)
                        .build();
            } else if (statusCode == 429) {
                return builder
                        .up()
                        .withData(KEY_STATUS, STATUS_DEGRADED)
                        .withData(KEY_REASON, "Rate limit exceeded - using cache")
                        .withData(KEY_RESPONSE_CODE, statusCode)
                        .build();
            } else {
                return builder
                        .up()
                        .withData(KEY_STATUS, STATUS_DEGRADED)
                        .withData(KEY_REASON, "Unexpected response")
                        .withData(KEY_RESPONSE_CODE, statusCode)
                        .build();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return builder
                    .up()
                    .withData(KEY_STATUS, STATUS_DEGRADED)
                    .withData(KEY_REASON, "API check interrupted - using cache")
                    .withData("error", e.getMessage())
                    .build();
        } catch (Exception e) {
            // External API being down shouldn't fail our readiness
            // We have cache fallback as per project requirements
            return builder
                    .up()
                    .withData(KEY_STATUS, STATUS_DEGRADED)
                    .withData(KEY_REASON, "API unreachable - using cache")
                    .withData("error", e.getMessage())
                    .build();
        }
    }
}
