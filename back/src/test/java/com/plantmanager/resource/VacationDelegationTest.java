package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for Vacation Delegation endpoints.
 * Covers: activate, cancel, status, delegations list, my-delegations,
 * permissions, validation, edge cases.
 *
 * Endpoints tested:
 *   POST   /houses/{id}/vacation       - Activate vacation mode
 *   DELETE /houses/{id}/vacation       - Cancel vacation mode
 *   GET    /houses/{id}/vacation       - Get vacation status
 *   GET    /houses/{id}/delegations    - List all house delegations
 *   GET    /houses/{id}/my-delegations - List received delegations
 */
@QuarkusTest
public class VacationDelegationTest {

    private String user1Token;
    private String user2Token;
    private String houseId;

    @BeforeEach
    void setUp() {
        user1Token = TestUtils.loginAsDemo();
        user2Token = TestUtils.loginAsTest2();

        // Get active house ID
        houseId = given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // Ensure user2 is in the same house by trying to join with invite code
        ensureUser2InSameHouse();

        // Clean up any existing vacation delegations
        cancelVacationIfActive(user1Token, houseId);
        cancelVacationIfActive(user2Token, houseId);
    }

    // ==================== HELPERS ====================

    private void ensureUser2InSameHouse() {
        // Get invite code from house
        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId)
                .then()
                .extract()
                .path("inviteCode");

        if (inviteCode != null) {
            // Try to join - may already be a member (409 is fine)
            given()
                    .header("Authorization", TestUtils.authHeader(user2Token))
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "inviteCode": "%s"
                            }
                            """.formatted(inviteCode))
                    .when()
                    .post("/houses/join");

            // Activate this house for user2
            given()
                    .header("Authorization", TestUtils.authHeader(user2Token))
                    .when()
                    .put("/houses/" + houseId + "/activate");
        }
    }

    private void cancelVacationIfActive(String token, String houseId) {
        Response status = given()
                .header("Authorization", TestUtils.authHeader(token))
                .when()
                .get("/houses/" + houseId + "/vacation");
        if (status.statusCode() == 200) {
            given()
                    .header("Authorization", TestUtils.authHeader(token))
                    .when()
                    .delete("/houses/" + houseId + "/vacation");
        }
    }

    private UUID getUser2Id() {
        List<Object> members = given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .extract()
                .path("$");

        // Get the first member that is NOT user1
        String user1Id = getUserIdFromToken(user1Token);
        for (Object member : members) {
            if (member instanceof java.util.Map<?, ?> map) {
                String memberId = map.get("userId").toString();
                if (!memberId.equals(user1Id)) {
                    return UUID.fromString(memberId);
                }
            }
        }
        return null;
    }

    private String getUserIdFromToken(String token) {
        // Decode JWT to extract subject (userId)
        String[] parts = token.split("\\.");
        if (parts.length >= 2) {
            String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
            // Simple extraction - look for "sub":"..."
            int subIdx = payload.indexOf("\"sub\"");
            if (subIdx >= 0) {
                int start = payload.indexOf("\"", subIdx + 5) + 1;
                int end = payload.indexOf("\"", start);
                return payload.substring(start, end);
            }
        }
        return null;
    }

    private String activateVacation(String token, String houseId, UUID delegateId,
                                     LocalDate startDate, LocalDate endDate, String message) {
        return given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s",
                            "message": %s
                        }
                        """.formatted(delegateId, startDate, endDate,
                        message != null ? "\"" + message + "\"" : "null"))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    // ==================== ACTIVATE VACATION ====================

    @Test
    void testActivateVacation_validData_shouldReturn201() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return; // skip if user2 not in house

        LocalDate start = LocalDate.now();
        LocalDate end = LocalDate.now().plusDays(7);

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s",
                            "message": "Partez en vacances, arrosez mes plantes svp!"
                        }
                        """.formatted(delegateId, start, end))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201)
                .body("id", notNullValue())
                .body("delegateId", equalTo(delegateId.toString()))
                .body("startDate", notNullValue())
                .body("endDate", notNullValue())
                .body("status", equalTo("ACTIVE"))
                .body("message", equalTo("Partez en vacances, arrosez mes plantes svp!"));
    }

    @Test
    void testActivateVacation_withoutMessage_shouldReturn201() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        LocalDate start = LocalDate.now();
        LocalDate end = LocalDate.now().plusDays(3);

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, start, end))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201)
                .body("status", equalTo("ACTIVE"));
    }

    @Test
    void testActivateVacation_singleDay_shouldReturn201() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        LocalDate today = LocalDate.now();

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, today, today))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201);
    }

    @Test
    void testActivateVacation_delegateToSelf_shouldReturn400() {
        String user1Id = getUserIdFromToken(user1Token);

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(user1Id, LocalDate.now(), LocalDate.now().plusDays(5)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_endDateBeforeStartDate_shouldReturn400() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, LocalDate.now().plusDays(5), LocalDate.now()))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_endDateInPast_shouldReturn400() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId,
                        LocalDate.now().minusDays(10),
                        LocalDate.now().minusDays(1)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_delegateNotInHouse_shouldReturn400() {
        UUID fakeUserId = UUID.randomUUID();

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(fakeUserId, LocalDate.now(), LocalDate.now().plusDays(5)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_alreadyOnVacation_shouldReturn400() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        // First activation
        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // Second activation should fail
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, LocalDate.now(), LocalDate.now().plusDays(10)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_delegateIsOnVacation_shouldReturn400() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        // First: user2 delegates to user1
        String user1Id = getUserIdFromToken(user1Token);
        given()
                .header("Authorization", TestUtils.authHeader(user2Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(user1Id, LocalDate.now(), LocalDate.now().plusDays(5)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201);

        // Now user1 tries to delegate to user2 (who is on vacation)
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, LocalDate.now(), LocalDate.now().plusDays(3)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    @Test
    void testActivateVacation_nonMemberHouse_shouldReturn403() {
        UUID fakeHouseId = UUID.randomUUID();
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, LocalDate.now(), LocalDate.now().plusDays(5)))
                .when()
                .post("/houses/" + fakeHouseId + "/vacation")
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
                        """.formatted(UUID.randomUUID(), LocalDate.now(), LocalDate.now().plusDays(5)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(401);
    }

    @Test
    void testActivateVacation_longDuration_shouldReturn201() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        // 90-day vacation
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, LocalDate.now(), LocalDate.now().plusDays(90)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201);
    }

    @Test
    void testActivateVacation_futureStartDate_shouldReturn201() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId,
                        LocalDate.now().plusDays(7),
                        LocalDate.now().plusDays(14)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201);
    }

    // ==================== CANCEL VACATION ====================

    @Test
    void testCancelVacation_active_shouldReturn204() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);
    }

    @Test
    void testCancelVacation_noActiveVacation_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(404);
    }

    @Test
    void testCancelVacation_afterCancel_statusShouldBe204() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // Cancel
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);

        // Status should show no active vacation (204 no content)
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);
    }

    @Test
    void testCancelVacation_thenReactivate_shouldWork() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        // Activate
        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // Cancel
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);

        // Re-activate with different dates
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, LocalDate.now(), LocalDate.now().plusDays(3)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201);
    }

    @Test
    void testCancelVacation_cancelTwice_shouldReturn404OnSecond() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // First cancel
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);

        // Second cancel
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(404);
    }

    @Test
    void testCancelVacation_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(401);
    }

    // ==================== VACATION STATUS ====================

    @Test
    void testGetVacationStatus_noVacation_shouldReturn204() {
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);
    }

    @Test
    void testGetVacationStatus_activeVacation_shouldReturn200() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), "Test message");

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(200)
                .body("status", equalTo("ACTIVE"))
                .body("delegateId", equalTo(delegateId.toString()))
                .body("message", equalTo("Test message"))
                .body("houseId", equalTo(houseId));
    }

    @Test
    void testGetVacationStatus_responseContainsAllFields() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(200)
                .body("id", notNullValue())
                .body("houseId", notNullValue())
                .body("delegatorId", notNullValue())
                .body("delegatorName", notNullValue())
                .body("delegateId", notNullValue())
                .body("delegateName", notNullValue())
                .body("startDate", notNullValue())
                .body("endDate", notNullValue())
                .body("status", notNullValue())
                .body("createdAt", notNullValue());
    }

    @Test
    void testGetVacationStatus_nonMemberHouse_shouldReturn403() {
        UUID fakeHouseId = UUID.randomUUID();

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + fakeHouseId + "/vacation")
                .then()
                .statusCode(403);
    }

    @Test
    void testGetVacationStatus_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(401);
    }

    // ==================== HOUSE DELEGATIONS ====================

    @Test
    void testGetHouseDelegations_noDelegations_shouldReturnEmptyList() {
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/delegations")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(0));
    }

    @Test
    void testGetHouseDelegations_withActiveDelegation_shouldReturnList() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/delegations")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(1))
                .body("[0].status", equalTo("ACTIVE"));
    }

    @Test
    void testGetHouseDelegations_visibleToAllMembers() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // user2 (the delegate) should also see the delegation
        given()
                .header("Authorization", TestUtils.authHeader(user2Token))
                .when()
                .get("/houses/" + houseId + "/delegations")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testGetHouseDelegations_cancelledNotShown() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // Cancel it
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);

        // Should no longer appear in active delegations
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/delegations")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(0));
    }

    @Test
    void testGetHouseDelegations_nonMemberHouse_shouldReturn403() {
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + UUID.randomUUID() + "/delegations")
                .then()
                .statusCode(403);
    }

    @Test
    void testGetHouseDelegations_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/houses/" + houseId + "/delegations")
                .then()
                .statusCode(401);
    }

    // ==================== MY DELEGATIONS (received) ====================

    @Test
    void testGetMyDelegations_noDelegations_shouldReturnEmptyList() {
        given()
                .header("Authorization", TestUtils.authHeader(user2Token))
                .when()
                .get("/houses/" + houseId + "/my-delegations")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(0));
    }

    @Test
    void testGetMyDelegations_asDelegate_shouldReturnDelegation() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), "Arrose mes plantes svp");

        // user2 should see the delegation they received
        given()
                .header("Authorization", TestUtils.authHeader(user2Token))
                .when()
                .get("/houses/" + houseId + "/my-delegations")
                .then()
                .statusCode(200)
                .body("$.size()", greaterThanOrEqualTo(1))
                .body("[0].status", equalTo("ACTIVE"))
                .body("[0].message", equalTo("Arrose mes plantes svp"));
    }

    @Test
    void testGetMyDelegations_asDelegator_shouldReturnEmptyList() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // user1 (the delegator) should NOT see it in "my-delegations"
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + houseId + "/my-delegations")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(0));
    }

    @Test
    void testGetMyDelegations_afterCancel_shouldReturnEmptyList() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // Cancel
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .delete("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(204);

        // user2 should no longer see it
        given()
                .header("Authorization", TestUtils.authHeader(user2Token))
                .when()
                .get("/houses/" + houseId + "/my-delegations")
                .then()
                .statusCode(200)
                .body("$.size()", equalTo(0));
    }

    @Test
    void testGetMyDelegations_nonMemberHouse_shouldReturn403() {
        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .when()
                .get("/houses/" + UUID.randomUUID() + "/my-delegations")
                .then()
                .statusCode(403);
    }

    @Test
    void testGetMyDelegations_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/houses/" + houseId + "/my-delegations")
                .then()
                .statusCode(401);
    }

    // ==================== MUTUAL DELEGATION EDGE CASES ====================

    @Test
    void testVacation_bothUsersCannotBeDelegators() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        String user1Id = getUserIdFromToken(user1Token);

        // User1 delegates to user2
        activateVacation(user1Token, houseId, delegateId,
                LocalDate.now(), LocalDate.now().plusDays(5), null);

        // User2 tries to delegate to user1 - should fail because user2 already has
        // an active delegation where they are the delegate (user1 is on vacation)
        // Actually the check is: delegate must not be on vacation themselves
        // Since user2 is NOT on vacation (they are the delegate), but user1 IS on vacation...
        // The code checks: "This member is currently on vacation and cannot accept delegations"
        // user1 is on vacation, so user2 cannot delegate to user1
        given()
                .header("Authorization", TestUtils.authHeader(user2Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(user1Id, LocalDate.now(), LocalDate.now().plusDays(3)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(400);
    }

    // ==================== RESPONSE DTO VALIDATION ====================

    @Test
    void testVacationResponse_datesShouldMatchRequest() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        LocalDate start = LocalDate.now().plusDays(1);
        LocalDate end = LocalDate.now().plusDays(10);

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, start, end))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201)
                .body("startDate", equalTo(start.toString()))
                .body("endDate", equalTo(end.toString()));
    }

    @Test
    void testVacationResponse_shouldContainDelegatorAndDelegateNames() {
        UUID delegateId = getUser2Id();
        if (delegateId == null) return;

        given()
                .header("Authorization", TestUtils.authHeader(user1Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "delegateId": "%s",
                            "startDate": "%s",
                            "endDate": "%s"
                        }
                        """.formatted(delegateId, LocalDate.now(), LocalDate.now().plusDays(5)))
                .when()
                .post("/houses/" + houseId + "/vacation")
                .then()
                .statusCode(201)
                .body("delegatorName", notNullValue())
                .body("delegatorName", not(emptyString()))
                .body("delegateName", notNullValue())
                .body("delegateName", not(emptyString()));
    }
}
