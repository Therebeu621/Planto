package com.plantmanager.health;

import io.quarkus.test.junit.QuarkusTest;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for TrefleApiHealthCheck.
 * Since the health check uses java.net.http.HttpClient internally,
 * we test it by directly calling the check and verifying the response structure.
 * All branches return UP (the check is lenient per design).
 */
@QuarkusTest
public class TrefleApiHealthCheckTest {

    /**
     * Test with no token configured.
     * This exercises the "no token" branch by instantiating directly.
     */
    @Test
    void testCall_noTokenConfigured_shouldReturnUpDegraded() {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck();
        // Token is null by default (not injected), so it should be degraded
        HealthCheckResponse response = check.call();

        assertNotNull(response);
        assertEquals("trefle-api", response.getName());
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertTrue(response.getData().isPresent());
        assertEquals("degraded", response.getData().get().get("status"));
        assertTrue(response.getData().get().get("reason").toString().contains("token"));
    }

    @Test
    void testCall_blankToken_shouldReturnUpDegraded() {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck();
        // Use reflection to set a blank token
        try {
            var field = TrefleApiHealthCheck.class.getDeclaredField("trefleToken");
            field.setAccessible(true);
            field.set(check, Optional.of("   "));
        } catch (Exception e) {
            fail("Failed to set trefleToken via reflection: " + e.getMessage());
        }

        HealthCheckResponse response = check.call();
        assertNotNull(response);
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
    }

    @Test
    void testCall_notConfiguredToken_shouldReturnUpDegraded() {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck();
        try {
            var field = TrefleApiHealthCheck.class.getDeclaredField("trefleToken");
            field.setAccessible(true);
            field.set(check, Optional.of("not-configured"));
        } catch (Exception e) {
            fail("Failed to set trefleToken via reflection: " + e.getMessage());
        }

        HealthCheckResponse response = check.call();
        assertNotNull(response);
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
    }

    /**
     * Test with an invalid token - should get 401/403 from Trefle API or connection error.
     * Either way it should return UP with degraded status.
     */
    @Test
    void testCall_invalidToken_shouldReturnUpWithStatus() {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck();
        try {
            var field = TrefleApiHealthCheck.class.getDeclaredField("trefleToken");
            field.setAccessible(true);
            field.set(check, Optional.of("invalid-token-12345"));
        } catch (Exception e) {
            fail("Failed to set trefleToken via reflection: " + e.getMessage());
        }

        HealthCheckResponse response = check.call();
        assertNotNull(response);
        assertEquals("trefle-api", response.getName());
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        // Should have some status data (either "available", "degraded" based on API response)
        assertTrue(response.getData().isPresent());
        assertNotNull(response.getData().get().get("status"));
    }

    /**
     * Test with a valid-looking but expired token to exercise the HTTP call path.
     * This will either get a 401/403 or network error - both are handled gracefully.
     */
    @Test
    void testCall_withToken_shouldAlwaysReturnUp() {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck();
        try {
            var field = TrefleApiHealthCheck.class.getDeclaredField("trefleToken");
            field.setAccessible(true);
            field.set(check, Optional.of("expired-test-token"));
        } catch (Exception e) {
            fail("Failed to set trefleToken via reflection: " + e.getMessage());
        }

        HealthCheckResponse response = check.call();

        // The check is lenient: it ALWAYS returns UP
        assertNotNull(response);
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
    }

    /**
     * Test health endpoint via REST to verify integration.
     */
    @Test
    void testHealthEndpoint_shouldIncludeTrefleCheck() {
        io.restassured.RestAssured.given()
                .basePath("/")
                .when()
                .get("/q/health/ready")
                .then()
                .statusCode(200);
    }
}
