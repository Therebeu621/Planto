package com.plantmanager.health;

import org.eclipse.microprofile.health.HealthCheckResponse;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for TrefleApiHealthCheck using a mocked HttpClient.
 * Tests all HTTP response code branches independently of network access.
 */
public class TrefleApiHealthCheckMockTest {

    private TrefleApiHealthCheck buildCheck(HttpClient mockClient, String token) throws Exception {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck(mockClient);
        var field = TrefleApiHealthCheck.class.getDeclaredField("trefleToken");
        field.setAccessible(true);
        field.set(check, Optional.of(token));
        return check;
    }

    @SuppressWarnings("unchecked")
    private HttpResponse<String> mockResponse(int statusCode) {
        HttpResponse<String> response = mock(HttpResponse.class);
        when(response.statusCode()).thenReturn(statusCode);
        return response;
    }

    // ==================== NO TOKEN / BLANK TOKEN ====================

    @Test
    void testCall_emptyToken_shouldReturnUpDegraded() {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck(mock(HttpClient.class));
        // trefleToken is null (not set) → orElse("") → blank → degraded
        HealthCheckResponse response = check.call();
        assertNotNull(response);
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
    }

    @Test
    void testCall_blankToken_shouldReturnUpDegraded() throws Exception {
        TrefleApiHealthCheck check = buildCheck(mock(HttpClient.class), "   ");
        HealthCheckResponse response = check.call();
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
        assertTrue(response.getData().get().get("reason").toString().contains("token"));
    }

    @Test
    void testCall_notConfiguredToken_shouldReturnUpDegraded() throws Exception {
        TrefleApiHealthCheck check = buildCheck(mock(HttpClient.class), "not-configured");
        HealthCheckResponse response = check.call();
        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
    }

    // ==================== HTTP 200 SUCCESS PATH ====================

    @Test
    @SuppressWarnings("unchecked")
    void testCall_http200_shouldReturnUpAvailable() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        HttpResponse<String> resp = mockResponse(200);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(resp);

        TrefleApiHealthCheck check = buildCheck(mockClient, "valid-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("available", response.getData().get().get("status"));
        assertEquals(200L, response.getData().get().get("responseCode"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void testCall_http201_shouldReturnUpAvailable() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        HttpResponse<String> resp = mockResponse(201);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(resp);

        TrefleApiHealthCheck check = buildCheck(mockClient, "valid-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("available", response.getData().get().get("status"));
    }

    // ==================== HTTP 401/403 INVALID TOKEN ====================

    @Test
    @SuppressWarnings("unchecked")
    void testCall_http401_shouldReturnUpDegradedInvalidToken() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        HttpResponse<String> resp = mockResponse(401);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(resp);

        TrefleApiHealthCheck check = buildCheck(mockClient, "invalid-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
        assertEquals("Invalid API token", response.getData().get().get("reason").toString());
        assertEquals(401L, response.getData().get().get("responseCode"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void testCall_http403_shouldReturnUpDegradedInvalidToken() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        HttpResponse<String> resp = mockResponse(403);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(resp);

        TrefleApiHealthCheck check = buildCheck(mockClient, "forbidden-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
        assertEquals("Invalid API token", response.getData().get().get("reason").toString());
        assertEquals(403L, response.getData().get().get("responseCode"));
    }

    // ==================== HTTP 429 RATE LIMIT ====================

    @Test
    @SuppressWarnings("unchecked")
    void testCall_http429_shouldReturnUpDegradedRateLimit() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        HttpResponse<String> resp = mockResponse(429);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(resp);

        TrefleApiHealthCheck check = buildCheck(mockClient, "rate-limited-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
        assertTrue(response.getData().get().get("reason").toString().contains("Rate limit"));
        assertEquals(429L, response.getData().get().get("responseCode"));
    }

    // ==================== HTTP UNEXPECTED RESPONSE ====================

    @Test
    @SuppressWarnings("unchecked")
    void testCall_http500_shouldReturnUpDegradedUnexpected() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        HttpResponse<String> resp = mockResponse(500);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(resp);

        TrefleApiHealthCheck check = buildCheck(mockClient, "some-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
        assertEquals("Unexpected response", response.getData().get().get("reason").toString());
        assertEquals(500L, response.getData().get().get("responseCode"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void testCall_http503_shouldReturnUpDegradedUnexpected() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        HttpResponse<String> resp = mockResponse(503);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(resp);

        TrefleApiHealthCheck check = buildCheck(mockClient, "some-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
    }

    // ==================== EXCEPTION PATHS ====================

    @Test
    @SuppressWarnings("unchecked")
    void testCall_ioException_shouldReturnUpDegradedUnreachable() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenThrow(new IOException("Connection refused"));

        TrefleApiHealthCheck check = buildCheck(mockClient, "some-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
        assertTrue(response.getData().get().get("reason").toString().contains("unreachable"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void testCall_runtimeException_shouldReturnUpDegradedUnreachable() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenThrow(new RuntimeException("Unexpected error"));

        TrefleApiHealthCheck check = buildCheck(mockClient, "some-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void testCall_interruptedException_shouldReturnUpDegradedInterrupted() throws Exception {
        HttpClient mockClient = mock(HttpClient.class);
        when(mockClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenThrow(new InterruptedException("Thread interrupted"));

        TrefleApiHealthCheck check = buildCheck(mockClient, "some-token");
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("degraded", response.getData().get().get("status"));
        assertTrue(response.getData().get().get("reason").toString().contains("interrupted"));
        // Verify thread interrupt status is restored
        assertTrue(Thread.interrupted()); // clears the flag too
    }

    // ==================== CHECK NAME ====================

    @Test
    void testCall_responseName_shouldBeTrefleApi() throws Exception {
        TrefleApiHealthCheck check = new TrefleApiHealthCheck(mock(HttpClient.class));
        HealthCheckResponse response = check.call();
        assertEquals("trefle-api", response.getName());
    }
}
