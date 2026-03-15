package com.plantmanager.health;

import io.agroal.api.AgroalDataSource;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.junit.jupiter.api.Test;

import java.sql.Connection;
import java.sql.SQLException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for DatabaseHealthCheck using mocked DataSource.
 * Tests the DOWN paths that cannot be triggered via REST endpoints
 * because the test database is always UP.
 */
public class DatabaseHealthCheckMockTest {

    private DatabaseHealthCheck buildCheck(AgroalDataSource mockDs) throws Exception {
        DatabaseHealthCheck check = new DatabaseHealthCheck();
        var field = DatabaseHealthCheck.class.getDeclaredField("dataSource");
        field.setAccessible(true);
        field.set(check, mockDs);
        return check;
    }

    // ==================== HAPPY PATH ====================

    @Test
    void testCall_validConnection_shouldReturnUp() throws Exception {
        AgroalDataSource mockDs = mock(AgroalDataSource.class);
        Connection mockConn = mock(Connection.class);
        when(mockDs.getConnection()).thenReturn(mockConn);
        when(mockConn.isValid(5)).thenReturn(true);

        DatabaseHealthCheck check = buildCheck(mockDs);
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("database", response.getName());
        assertTrue(response.getData().isPresent());
        assertEquals("valid", response.getData().get().get("connection").toString());
    }

    // ==================== DOWN PATHS ====================

    @Test
    void testCall_connectionNotValid_shouldReturnDown() throws Exception {
        AgroalDataSource mockDs = mock(AgroalDataSource.class);
        Connection mockConn = mock(Connection.class);
        when(mockDs.getConnection()).thenReturn(mockConn);
        when(mockConn.isValid(5)).thenReturn(false);

        DatabaseHealthCheck check = buildCheck(mockDs);
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.DOWN, response.getStatus());
        assertEquals("database", response.getName());
        assertTrue(response.getData().isPresent());
        assertTrue(response.getData().get().get("error").toString().contains("validation failed"));
    }

    @Test
    void testCall_sqlException_shouldReturnDown() throws Exception {
        AgroalDataSource mockDs = mock(AgroalDataSource.class);
        when(mockDs.getConnection()).thenThrow(new SQLException("Cannot connect to database"));

        DatabaseHealthCheck check = buildCheck(mockDs);
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.DOWN, response.getStatus());
        assertEquals("database", response.getName());
        assertTrue(response.getData().isPresent());
        assertTrue(response.getData().get().get("error").toString().contains("Cannot connect"));
    }

    @Test
    void testCall_sqlExceptionWithNullMessage_shouldReturnDown() throws Exception {
        AgroalDataSource mockDs = mock(AgroalDataSource.class);
        when(mockDs.getConnection()).thenThrow(new SQLException((String) null));

        DatabaseHealthCheck check = buildCheck(mockDs);
        HealthCheckResponse response = check.call();

        assertEquals(HealthCheckResponse.Status.DOWN, response.getStatus());
    }
}
