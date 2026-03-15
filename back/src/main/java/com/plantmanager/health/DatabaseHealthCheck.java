package com.plantmanager.health;

import io.agroal.api.AgroalDataSource;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.HealthCheckResponseBuilder;
import org.eclipse.microprofile.health.Liveness;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * Database liveness health check.
 * Verifies that the application can connect to PostgreSQL.
 * Used by Kubernetes liveness probe at /q/health/live
 */
@Liveness
@ApplicationScoped
public class DatabaseHealthCheck implements HealthCheck {

    private static final String CHECK_NAME = "database";

    @Inject
    AgroalDataSource dataSource;

    @Override
    public HealthCheckResponse call() {
        HealthCheckResponseBuilder builder = HealthCheckResponse.named(CHECK_NAME);

        try (Connection connection = dataSource.getConnection()) {
            // Execute simple query to verify connection
            boolean valid = connection.isValid(5); // 5 second timeout

            if (valid) {
                return builder
                        .up()
                        .withData(CHECK_NAME, "PostgreSQL")
                        .withData("connection", "valid")
                        .build();
            } else {
                return builder
                        .down()
                        .withData("error", "Connection validation failed")
                        .build();
            }
        } catch (SQLException e) {
            return builder
                    .down()
                    .withData("error", e.getMessage())
                    .build();
        }
    }
}
