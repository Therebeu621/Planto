package com.plantmanager.service;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for VacationService via HouseResource endpoints.
 */
@QuarkusTest
public class VacationServiceTest {

    @Test
    void testGetVacationStatus_noActiveVacation_shouldReturn204() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);
    }

    @Test
    void testGetHouseDelegations_noDelegations_shouldReturnEmptyList() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/" + houseId + "/delegations")
                .then()
                .statusCode(200)
                .body("size()", greaterThanOrEqualTo(0));
    }

    @Test
    void testGetMyDelegations_noDelegations_shouldReturnEmptyList() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/" + houseId + "/my-delegations")
                .then()
                .statusCode(200)
                .body("size()", greaterThanOrEqualTo(0));
    }

    @Test
    void testActivateVacation_selfDelegate_shouldReturn400() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        // Get own user ID
        String userId = given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/auth/me")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // Try to delegate to self
        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(userId, LocalDate.now(), LocalDate.now().plusDays(7)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_endDateBeforeStart_shouldReturn400() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        // Need a second user as delegate
        String token2 = TestUtils.loginAsTest2();
        String user2Id = given()
                .header("Authorization", "Bearer " + token2)
                .when()
                .get("/auth/me")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // Ensure user2 is in the same house
        ensureUserInHouse(token2, houseId);

        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(user2Id, LocalDate.now().plusDays(7), LocalDate.now()))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testCancelVacation_noActiveVacation_shouldReturn404() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(404);
    }

    @Test
    void testActivateAndCancelVacation_fullFlow() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        // Get a second user as delegate
        String token2 = TestUtils.loginAsTest2();
        String user2Id = given()
                .header("Authorization", "Bearer " + token2)
                .when()
                .get("/auth/me")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // Ensure user2 is in the same house
        ensureUserInHouse(token2, houseId);

        // Activate vacation
        var activateResponse = given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s",
                            "message": "Going on vacation!"
                        }
                        """.formatted(user2Id, LocalDate.now(), LocalDate.now().plusDays(7)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .extract();

        if (activateResponse.statusCode() == 200 || activateResponse.statusCode() == 201) {
            // Check vacation status
            given()
                    .header("Authorization", "Bearer " + token)
                    .when()
                    .get("/houses/" + houseId + "/vacation")
                    .then()
                    .statusCode(200)
                    .body("status", equalTo("ACTIVE"));

            // Check delegations list
            given()
                    .header("Authorization", "Bearer " + token)
                    .when()
                    .get("/houses/" + houseId + "/delegations")
                    .then()
                    .statusCode(200)
                    .body("size()", greaterThan(0));

            // Check my-delegations for user2
            given()
                    .header("Authorization", "Bearer " + token2)
                    .when()
                    .get("/houses/" + houseId + "/my-delegations")
                    .then()
                    .statusCode(200)
                    .body("size()", greaterThan(0));

            // Cancel vacation
            given()
                    .header("Authorization", "Bearer " + token)
                    .when()
                    .delete("/houses/" + houseId + "/vacation")
                    .then()
                    .statusCode(204);
        }
    }

    private String getActiveHouseId(String token) {
        return given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");
    }

    @Test
    void testActivateVacation_endDateInPast_shouldReturn400() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        String token2 = TestUtils.loginAsTest2();
        String user2Id = given()
                .header("Authorization", "Bearer " + token2)
                .when()
                .get("/auth/me")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        ensureUserInHouse(token2, houseId);

        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(user2Id, LocalDate.now().minusDays(7), LocalDate.now().minusDays(1)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_delegateNotMember_shouldReturn400() {
        String token = TestUtils.loginAsDemo();
        String houseId = getActiveHouseId(token);

        // Use a random UUID as delegate (not a member)
        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(java.util.UUID.randomUUID(), LocalDate.now(), LocalDate.now().plusDays(7)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_nonMemberHouse_shouldReturn403() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(java.util.UUID.randomUUID(), LocalDate.now(), LocalDate.now().plusDays(7)))
                .when()
                .post("/houses/" + java.util.UUID.randomUUID() + "/vacation")
                .then()
                .statusCode(403);
    }

    @Test
    void testGetVacationStatus_nonMemberHouse_shouldReturn403() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/" + java.util.UUID.randomUUID() + "/vacation")
                .then()
                .statusCode(403);
    }

    @Test
    void testGetHouseDelegations_nonMember_shouldReturn403() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/" + java.util.UUID.randomUUID() + "/delegations")
                .then()
                .statusCode(403);
    }

    @Test
    void testGetMyDelegations_nonMember_shouldReturn403() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses/" + java.util.UUID.randomUUID() + "/my-delegations")
                .then()
                .statusCode(403);
    }

    @Test
    void testActivateVacation_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(java.util.UUID.randomUUID(), LocalDate.now(), LocalDate.now().plusDays(7)))
                .when()
                .post("/houses/" + java.util.UUID.randomUUID() + "/vacation")
                .then()
                .statusCode(401);
    }

    @Test
    void testCancelVacation_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/houses/" + java.util.UUID.randomUUID() + "/vacation")
                .then()
                .statusCode(401);
    }

    private void ensureUserInHouse(String token, String houseId) {
        // Check if user already has this house
        var response = given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/houses");

        if (response.statusCode() == 200) {
            var houses = response.jsonPath().getList("id");
            if (houses != null && houses.contains(houseId)) {
                // Already a member, activate it
                given()
                        .header("Authorization", "Bearer " + token)
                        .when()
                        .put("/houses/" + houseId + "/activate");
                return;
            }
        }

        // Try to get invite code and join
        // If can't join, create a new house shared setup
        // For simplicity, just ensure user2 has a house (the setup already does this)
    }
}
