package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for IotSensorResource endpoints.
 * Tests IoT sensor CRUD, readings submission, and readings retrieval.
 */
@QuarkusTest
public class IotSensorResourceTest {

    private String accessToken;
    private String houseId;
    private UUID roomId;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
        houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");
        roomId = TestUtils.firstRoomId(accessToken);
    }

    // ==================== POST /iot/house/{houseId}/sensors ====================

    @Test
    void testCreateSensor_validData_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "HUMIDITY",
                            "deviceId": "ESP32-%s",
                            "label": "Capteur salon"
                        }
                        """.formatted(UUID.randomUUID().toString().substring(0, 8)))
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(201)
                .body("id", notNullValue())
                .body("sensorType", equalTo("HUMIDITY"))
                .body("label", equalTo("Capteur salon"));
    }

    @Test
    void testCreateSensor_allTypes_shouldReturn201() {
        for (String type : new String[]{"HUMIDITY", "TEMPERATURE", "LUMINOSITY", "SOIL_PH"}) {
            given()
                    .header("Authorization", TestUtils.authHeader(accessToken))
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "sensorType": "%s",
                                "deviceId": "ESP-%s-%s"
                            }
                            """.formatted(type, type, UUID.randomUUID().toString().substring(0, 6)))
                    .when()
                    .post("/iot/house/" + houseId + "/sensors")
                    .then()
                    .statusCode(201)
                    .body("sensorType", equalTo(type));
        }
    }

    @Test
    void testCreateSensor_withPlantId_shouldReturn201() {
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "IoT Plant " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "TEMPERATURE",
                            "deviceId": "ESP-PLANT-%s",
                            "plantId": "%s"
                        }
                        """.formatted(UUID.randomUUID().toString().substring(0, 8), plantId))
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(201);
    }

    @Test
    void testCreateSensor_missingSensorType_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "deviceId": "ESP-NO-TYPE"
                        }
                        """)
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateSensor_missingDeviceId_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "HUMIDITY"
                        }
                        """)
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateSensor_invalidSensorType_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "INVALID_TYPE",
                            "deviceId": "ESP-INVALID"
                        }
                        """)
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(400);
    }

    @Test
    void testCreateSensor_nonExistentHouse_shouldReturn403or404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "HUMIDITY",
                            "deviceId": "ESP-ORPHAN"
                        }
                        """)
                .when()
                .post("/iot/house/" + UUID.randomUUID() + "/sensors")
                .then()
                .statusCode(anyOf(is(403), is(404)));
    }

    @Test
    void testCreateSensor_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "HUMIDITY",
                            "deviceId": "ESP-NOAUTH"
                        }
                        """)
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(401);
    }

    @Test
    void testCreateSensor_deviceIdTooLong_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "HUMIDITY",
                            "deviceId": "%s"
                        }
                        """.formatted("X".repeat(101)))
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(400);
    }

    // ==================== GET /iot/house/{houseId}/sensors ====================

    @Test
    void testGetSensorsByHouse_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetSensorsByHouse_nonExistentHouse_shouldReturn403or404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/house/" + UUID.randomUUID() + "/sensors")
                .then()
                .statusCode(anyOf(is(403), is(404)));
    }

    @Test
    void testGetSensorsByHouse_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(401);
    }

    // ==================== GET /iot/plant/{plantId}/sensors ====================

    @Test
    void testGetSensorsByPlant_shouldReturn200() {
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Sensor Plant " + UUID.randomUUID());

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/plant/" + plantId + "/sensors")
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetSensorsByPlant_nonExistentPlant_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/plant/" + UUID.randomUUID() + "/sensors")
                .then()
                .statusCode(404);
    }

    @Test
    void testGetSensorsByPlant_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/iot/plant/" + UUID.randomUUID() + "/sensors")
                .then()
                .statusCode(401);
    }

    // ==================== POST /iot/sensors/{sensorId}/readings ====================

    @Test
    void testSubmitReading_validData_shouldReturn201() {
        String sensorId = createSensor("HUMIDITY", "ESP-READ-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 65.5
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201)
                .body("value", isA(Number.class))
                .body("id", notNullValue());
    }

    @Test
    void testSubmitReading_zeroValue_shouldReturn201() {
        String sensorId = createSensor("TEMPERATURE", "ESP-ZERO-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 0
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201);
    }

    @Test
    void testSubmitReading_negativeValue_shouldReturn201() {
        String sensorId = createSensor("TEMPERATURE", "ESP-NEG-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": -10.5
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201);
    }

    @Test
    void testSubmitReading_missingValue_shouldReturn400() {
        String sensorId = createSensor("HUMIDITY", "ESP-NOVAL-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(400);
    }

    @Test
    void testSubmitReading_nonExistentSensor_shouldReturn404() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 50.0
                        }
                        """)
                .when()
                .post("/iot/sensors/" + UUID.randomUUID() + "/readings")
                .then()
                .statusCode(404);
    }

    @Test
    void testSubmitReading_isPermitAll_noAuthRequired() {
        // PermitAll endpoint - should work without auth
        String sensorId = createSensor("LUMINOSITY", "ESP-NOAUTH-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 800
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201);
    }

    @Test
    void testSubmitReading_largeValue_shouldReturn201() {
        String sensorId = createSensor("LUMINOSITY", "ESP-LARGE-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 99999.99
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201);
    }

    @Test
    void testSubmitReading_preciseDecimalValue_shouldReturn201() {
        String sensorId = createSensor("SOIL_PH", "ESP-PH-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 6.87
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201);
    }

    // ==================== GET /iot/sensors/{sensorId}/readings ====================

    @Test
    void testGetReadings_shouldReturn200() {
        String sensorId = createSensor("HUMIDITY", "ESP-HIST-" + UUID.randomUUID().toString().substring(0, 6));

        // Submit some readings first
        for (int i = 0; i < 3; i++) {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "value": %d
                            }
                            """.formatted(50 + i * 10))
                    .when()
                    .post("/iot/sensors/" + sensorId + "/readings")
                    .then()
                    .statusCode(201);
        }

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class))
                .body("size()", greaterThanOrEqualTo(3));
    }

    @Test
    void testGetReadings_withLimit_shouldReturn200() {
        String sensorId = createSensor("TEMPERATURE", "ESP-LIM-" + UUID.randomUUID().toString().substring(0, 6));

        for (int i = 0; i < 5; i++) {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "value": %d
                            }
                            """.formatted(20 + i))
                    .when()
                    .post("/iot/sensors/" + sensorId + "/readings");
        }

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("limit", 2)
                .when()
                .get("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(200)
                .body("size()", lessThanOrEqualTo(2));
    }

    @Test
    void testGetReadings_nonExistentSensor_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/sensors/" + UUID.randomUUID() + "/readings")
                .then()
                .statusCode(404);
    }

    @Test
    void testGetReadings_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/iot/sensors/" + UUID.randomUUID() + "/readings")
                .then()
                .statusCode(401);
    }

    // ==================== DELETE /iot/sensors/{sensorId} ====================

    @Test
    void testDeleteSensor_existing_shouldReturn204() {
        String sensorId = createSensor("HUMIDITY", "ESP-DEL-" + UUID.randomUUID().toString().substring(0, 6));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/iot/sensors/" + sensorId)
                .then()
                .statusCode(204);
    }

    @Test
    void testDeleteSensor_nonExistent_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/iot/sensors/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testDeleteSensor_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/iot/sensors/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== FULL LIFECYCLE ====================

    @Test
    void testSensorLifecycle_createSubmitReadDelete() {
        // CREATE
        String sensorId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "HUMIDITY",
                            "deviceId": "ESP-LIFECYCLE-%s",
                            "label": "Test lifecycle"
                        }
                        """.formatted(UUID.randomUUID().toString().substring(0, 6)))
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // LIST - sensor should appear
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(200)
                .body("find { it.id == '%s' }".formatted(sensorId), notNullValue());

        // SUBMIT READINGS
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 72.3
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201);

        // READ HISTORY
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(200)
                .body("size()", greaterThanOrEqualTo(1));

        // DELETE
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/iot/sensors/" + sensorId)
                .then()
                .statusCode(204);
    }

    // ==================== DATE RANGE READINGS ====================

    @Test
    void testGetReadings_withDateRange_shouldReturn200() {
        String sensorId = createSensor("TEMPERATURE", "ESP-RANGE-" + UUID.randomUUID().toString().substring(0, 6));

        // Submit a reading
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "value": 25.5
                        }
                        """)
                .when()
                .post("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(201);

        // Query with date range
        String from = java.time.OffsetDateTime.now().minusDays(1).toString();
        String to = java.time.OffsetDateTime.now().plusDays(1).toString();

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("from", from)
                .queryParam("to", to)
                .when()
                .get("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(200)
                .body("size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testDeleteSensor_withReadings_shouldCascadeDelete() {
        String sensorId = createSensor("HUMIDITY", "ESP-CASCADE-" + UUID.randomUUID().toString().substring(0, 6));

        // Submit readings
        for (int i = 0; i < 3; i++) {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "value": %d
                            }
                            """.formatted(40 + i * 5))
                    .when()
                    .post("/iot/sensors/" + sensorId + "/readings")
                    .then()
                    .statusCode(201);
        }

        // Delete sensor should cascade
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/iot/sensors/" + sensorId)
                .then()
                .statusCode(204);

        // Verify it's gone
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/iot/sensors/" + sensorId + "/readings")
                .then()
                .statusCode(404);
    }

    // ==================== HELPER ====================

    private String createSensor(String type, String deviceId) {
        return given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "sensorType": "%s",
                            "deviceId": "%s"
                        }
                        """.formatted(type, deviceId))
                .when()
                .post("/iot/house/" + houseId + "/sensors")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
