package com.plantmanager.health;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Liveness;

/**
 * Application liveness health check.
 * Simple check that the application is running.
 * Used by Kubernetes liveness probe at /q/health/live
 */
@Liveness
@ApplicationScoped
public class ApplicationHealthCheck implements HealthCheck {

    private static final String CHECK_NAME = "application";

    @Override
    public HealthCheckResponse call() {
        return HealthCheckResponse.named(CHECK_NAME)
                .up()
                .withData("name", "plant-backend")
                .withData("version", "1.0.0")
                .build();
    }
}
