package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Comprehensive integration tests for GUEST role permissions.
 * Tests OWNER > MEMBER > GUEST hierarchy, access control, and edge cases.
 *
 * Note: @RolesAllowed checks use the JWT global role (always MEMBER for regular users).
 * House-level role (OWNER/MEMBER/GUEST) is enforced by HouseService for member management.
 * Room/Plant endpoints do NOT enforce house-level GUEST restrictions (known limitation).
 */
@QuarkusTest
public class GuestRoleTest {

    private String ownerToken;
    private String test2Token;

    @BeforeEach
    void setUp() {
        ownerToken = TestUtils.loginAsDemo();
        test2Token = TestUtils.loginAsTest2();
    }

    // ── helpers ──────────────────────────────────────────────────────

    private String createHouse(String name) {
        return given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "name": "%s" }
                        """.formatted(name))
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    private String getInviteCode(String houseId) {
        return given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .extract()
                .path("inviteCode");
    }

    private void joinAsTest2(String inviteCode) {
        // 1. Send join request (creates pending invitation)
        String invitationId = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        { "inviteCode": "%s" }
                        """.formatted(inviteCode))
                .when()
                .post("/houses/join")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // 2. Owner accepts the invitation
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .put("/houses/invitations/" + invitationId + "/accept")
                .then()
                .statusCode(200);
    }

    private String getMemberUserId(String houseId) {
        return given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.role == 'MEMBER' }.userId");
    }

    private String getOwnerUserId(String houseId) {
        return given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.role == 'OWNER' }.userId");
    }

    private void demoteToGuest(String houseId, String userId) {
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "GUEST" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + userId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("GUEST"));
    }

    private void activateHouse(String token, String houseId) {
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .when()
                .put("/houses/" + houseId + "/activate")
                .then()
                .statusCode(200);
    }

    /** Creates a house, has test2 join, demotes test2 to GUEST. Returns [houseId, guestUserId]. */
    private String[] setupHouseWithGuest(String houseName) {
        String houseId = createHouse(houseName);
        String inviteCode = getInviteCode(houseId);
        joinAsTest2(inviteCode);
        String userId = getMemberUserId(houseId);
        demoteToGuest(houseId, userId);
        return new String[]{houseId, userId};
    }

    // ==================== ROLE ASSIGNMENT TESTS ====================

    @Test
    void testOwnerCanDemoteMemberToGuest() {
        String houseId = createHouse("Demote To Guest House");
        String inviteCode = getInviteCode(houseId);
        joinAsTest2(inviteCode);
        String userId = getMemberUserId(houseId);

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "GUEST" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + userId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("GUEST"));

        // Verify via members list
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("find { it.userId == '%s' }.role".formatted(userId), equalTo("GUEST"));
    }

    @Test
    void testOwnerCanPromoteGuestToMember() {
        String[] setup = setupHouseWithGuest("Promote Guest To Member");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "MEMBER" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + guestUserId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("MEMBER"));
    }

    @Test
    void testOwnerCanPromoteGuestToOwner() {
        String[] setup = setupHouseWithGuest("Promote Guest To Owner");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "OWNER" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + guestUserId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("OWNER"));
    }

    @Test
    void testJoiningHouseDefaultsToMemberNotGuest() {
        String houseId = createHouse("Default Role House");
        String inviteCode = getInviteCode(houseId);

        // Send join request
        String invitationId = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        { "inviteCode": "%s" }
                        """.formatted(inviteCode))
                .when()
                .post("/houses/join")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Owner accepts
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .put("/houses/invitations/" + invitationId + "/accept")
                .then()
                .statusCode(200);

        // Verify test2 joined as MEMBER
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("find { it.role == 'MEMBER' }.role", equalTo("MEMBER"));
    }

    // ==================== GUEST READ ACCESS TESTS ====================

    @Test
    void testGuestCanViewHouseMembers() {
        String[] setup = setupHouseWithGuest("Guest View Members");
        String houseId = setup[0];
        activateHouse(test2Token, houseId);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testGuestCanViewHouseDetails() {
        String[] setup = setupHouseWithGuest("Guest View Details");
        String houseId = setup[0];

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .body("id", equalTo(houseId))
                .body("name", notNullValue());
    }

    @Test
    void testGuestCanListOwnHouses() {
        setupHouseWithGuest("Guest List Houses");

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/houses")
                .then()
                .statusCode(200)
                .body("size()", greaterThanOrEqualTo(1));
    }

    @Test
    void testGuestCanViewRooms() {
        String[] setup = setupHouseWithGuest("Guest View Rooms");
        String houseId = setup[0];
        activateHouse(test2Token, houseId);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/rooms")
                .then()
                .statusCode(200);
    }

    @Test
    void testGuestCanViewPlants() {
        String[] setup = setupHouseWithGuest("Guest View Plants");
        String houseId = setup[0];
        activateHouse(test2Token, houseId);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/plants")
                .then()
                .statusCode(200);
    }

    // ==================== GUEST FORBIDDEN ACTIONS (House management) ====================

    @Test
    void testGuestCannotUpdateMemberRole_shouldReturn403() {
        String[] setup = setupHouseWithGuest("Guest No Role Update");
        String houseId = setup[0];
        String ownerUserId = getOwnerUserId(houseId);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "MEMBER" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + ownerUserId + "/role")
                .then()
                .statusCode(403);
    }

    @Test
    void testGuestCannotRemoveOtherMember_shouldReturn403() {
        String[] setup = setupHouseWithGuest("Guest No Remove");
        String houseId = setup[0];
        String ownerUserId = getOwnerUserId(houseId);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .delete("/houses/" + houseId + "/members/" + ownerUserId)
                .then()
                .statusCode(403);
    }

    @Test
    void testGuestCannotDeleteHouse_shouldReturn403() {
        String[] setup = setupHouseWithGuest("Guest No Delete House");
        String houseId = setup[0];

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .delete("/houses/" + houseId)
                .then()
                .statusCode(403);
    }

    // ==================== EDGE CASES ====================

    @Test
    void testOwnerCannotSetInvalidRole_shouldReturn400() {
        String[] setup = setupHouseWithGuest("Invalid Role House");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "SUPER_ADMIN" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + guestUserId + "/role")
                .then()
                .statusCode(400);
    }

    @Test
    void testOwnerCannotSetEmptyRole_shouldReturn400() {
        String[] setup = setupHouseWithGuest("Empty Role House");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + guestUserId + "/role")
                .then()
                .statusCode(400);
    }

    @Test
    void testGuestCannotPromoteSelfToMember_shouldReturn403() {
        String[] setup = setupHouseWithGuest("Guest Self Promote Member");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "MEMBER" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + guestUserId + "/role")
                .then()
                .statusCode(403);
    }

    @Test
    void testGuestCannotPromoteSelfToOwner_shouldReturn403() {
        String[] setup = setupHouseWithGuest("Guest Self Promote Owner");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "OWNER" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + guestUserId + "/role")
                .then()
                .statusCode(403);
    }

    @Test
    void testGuestCannotRemoveSelfViaMemberEndpoint_shouldReturn400() {
        // Backend returns 400 "cannot remove yourself" (use /leave instead)
        String[] setup = setupHouseWithGuest("Guest Self Remove");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .delete("/houses/" + houseId + "/members/" + guestUserId)
                .then()
                .statusCode(400);
    }

    @Test
    void testOwnerCanRemoveGuest() {
        String[] setup = setupHouseWithGuest("Owner Remove Guest");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .delete("/houses/" + houseId + "/members/" + guestUserId)
                .then()
                .statusCode(204);

        // Verify only owner remains
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("size()", equalTo(1))
                .body("[0].role", equalTo("OWNER"));
    }

    @Test
    void testGuestRoleAppearsInMembersList() {
        String[] setup = setupHouseWithGuest("Guest In Members List");
        String houseId = setup[0];

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("role", hasItem("GUEST"))
                .body("role", hasItem("OWNER"));
    }

    @Test
    void testGuestCanLeaveHouse() {
        String[] setup = setupHouseWithGuest("Guest Leave House");
        String houseId = setup[0];

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .delete("/houses/" + houseId + "/leave")
                .then()
                .statusCode(204);

        // Verify only owner remains
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("size()", equalTo(1));
    }

    @Test
    void testRoleTransitionChain_GuestToMemberToOwner() {
        String houseId = createHouse("Role Chain House");
        String inviteCode = getInviteCode(houseId);
        joinAsTest2(inviteCode);
        String userId = getMemberUserId(houseId);

        // MEMBER -> GUEST
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "GUEST" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + userId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("GUEST"));

        // GUEST -> MEMBER
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "MEMBER" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + userId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("MEMBER"));

        // MEMBER -> OWNER
        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "OWNER" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + userId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("OWNER"));
    }

    @Test
    void testSetRoleToSameRole_shouldReturn200() {
        String[] setup = setupHouseWithGuest("Same Role House");
        String houseId = setup[0];
        String guestUserId = setup[1];

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "GUEST" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + guestUserId + "/role")
                .then()
                .statusCode(200)
                .body("role", equalTo("GUEST"));
    }

    @Test
    void testMemberCannotUpdateRoleEither_shouldReturn403() {
        // Even a MEMBER (not GUEST, not OWNER) cannot update roles
        String houseId = createHouse("Member No Role Update");
        String inviteCode = getInviteCode(houseId);
        joinAsTest2(inviteCode);
        String ownerUserId = getOwnerUserId(houseId);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        { "role": "GUEST" }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + ownerUserId + "/role")
                .then()
                .statusCode(403);
    }

    @Test
    void testMemberCannotRemoveOtherMember_shouldReturn403() {
        String houseId = createHouse("Member No Remove");
        String inviteCode = getInviteCode(houseId);
        joinAsTest2(inviteCode);
        String ownerUserId = getOwnerUserId(houseId);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .delete("/houses/" + houseId + "/members/" + ownerUserId)
                .then()
                .statusCode(403);
    }
}
