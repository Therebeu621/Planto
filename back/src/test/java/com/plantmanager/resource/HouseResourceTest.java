package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
public class HouseResourceTest {

    private String accessToken;

    @BeforeEach
    void setUp() {
        // Login with demo user (creates user + default house if needed)
        accessToken = TestUtils.loginAsDemo();
    }

    @Test
    void testGetMyHouses_shouldReturnHouseList() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .body("size()", greaterThanOrEqualTo(1))
                .body("name", hasItem(notNullValue()));
    }

    @Test
    void testGetActiveHouse_shouldReturnHouseDetails() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .body("id", notNullValue())
                .body("name", notNullValue());
    }

    @Test
    void testCreateHouse_validData_shouldReturn201() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "New Vacation House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .body("name", equalTo("New Vacation House"))
                .body("role", equalTo("OWNER"));
    }

    @Test
    void testCreateHouse_blankName_shouldReturn400WithCleanMessage() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": ""
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(400)
                .body("message", equalTo("Le nom de la maison est requis"));
    }

    @Test
    void testSwitchActiveHouse_shouldUpdateContext() {
        // 1. Create a new house
        String newHouseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Switch Target House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // 2. Switch to it
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .put("/houses/" + newHouseId + "/activate")
                .then()
                .statusCode(200)
                .body("id", equalTo(newHouseId))
                .body("isActive", is(true));

        // 3. Verify it's now the active house
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .body("id", equalTo(newHouseId));
    }

    /** Helper: test2 sends join request, owner accepts it. */
    private void joinAndAccept(String ownerToken, String test2Token, String inviteCode) {
        String invitationId = given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "inviteCode": "%s"
                        }
                        """.formatted(inviteCode))
                .when()
                .post("/houses/join")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(ownerToken))
                .when()
                .put("/houses/invitations/" + invitationId + "/accept")
                .then()
                .statusCode(200);
    }

    @Test
    void testJoinHouse_validCode_shouldJoin() {
        // 1. Create a house as Demo User
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Joinable House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .extract()
                .path("inviteCode");

        // 2. Login as Test2 User
        String test2Token = TestUtils.loginAsTest2();

        // 3. Join + accept
        joinAndAccept(accessToken, test2Token, inviteCode);

        // 4. Verify test2 is now a MEMBER
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("find { it.role == 'MEMBER' }.role", equalTo("MEMBER"));
    }

    @Test
    void testMemberManagement_shouldManageMembers() {
        // 1. Create house and get invite code
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Member Mgmt House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .extract()
                .path("inviteCode");

        // 2. Add Test2 as member
        String test2Token = TestUtils.loginAsTest2();
        joinAndAccept(accessToken, test2Token, inviteCode);

        // 3. Get members list (as Owner)
        String test2UserId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("size()", equalTo(2)) // Owner + Member
                .extract()
                .path("find { it.role == 'MEMBER' }.userId");

        // 4. Update member role to ADMIN (actually MEMBER or OWNER are allowed roles enum? Check HouseResource)
        // HouseResource.updateMemberRole calls HouseService which validates specific logic.
        // Assuming OWNER can promote to OWNER or keep as MEMBER.
        // Let's try to remove member since update logic might be complex with enum validity.
        
        // 5. Remove member (as Owner)
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/houses/" + houseId + "/members/" + test2UserId)
                .then()
                .statusCode(204);

        // 6. Verify member count is back to 1
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("size()", equalTo(1));
    }

    @Test
    void testLeaveHouse_shouldLeave() {
        // 1. Create house as Demo User
        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "House To Leave"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("inviteCode");
        
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // 2. Login as Test2 User and join
        String test2Token = TestUtils.loginAsTest2();
        
        // Need to join successfully first
        joinAndAccept(accessToken, test2Token, inviteCode);

        // 3. Leave house as Test2
        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .delete("/houses/" + houseId + "/leave")
                .then()
                .statusCode(204);

        // 4. Verify Test2 is no longer a member
        // (Login as Test2 and check my houses)
        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .get("/houses")
                .then()
                .statusCode(200)
                .body("find { it.id == '%s' }".formatted(houseId), nullValue());
    }

    @Test
    void testJoinHouse_invalidCode_shouldReturn404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "inviteCode": "INVALID1"
                        }
                        """)
                .when()
                .post("/houses/join")
                .then()
                .statusCode(404);
    }

    @Test
    void testLeaveHouse_onlyOwner_shouldReturn400() {
        String ownerHouseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Owner Only House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/houses/" + ownerHouseId + "/leave")
                .then()
                .statusCode(400);
    }

    @Test
    void testUpdateMemberRole_ownerPromoteMember_shouldReturn200() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Role Update House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .extract()
                .path("inviteCode");

        String test2Token = TestUtils.loginAsTest2();
        joinAndAccept(accessToken, test2Token, inviteCode);

        String test2UserId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.email == '%s' }.userId".formatted(TestUtils.TEST2_EMAIL));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "role": "OWNER"
                        }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + test2UserId + "/role")
                .then()
                .statusCode(200)
                .body("userId", equalTo(test2UserId))
                .body("role", equalTo("OWNER"));
    }

    @Test
    void testUpdateMemberRole_invalidRole_shouldReturn400() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Invalid Role House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .extract()
                .path("inviteCode");

        String test2Token = TestUtils.loginAsTest2();
        joinAndAccept(accessToken, test2Token, inviteCode);

        String test2UserId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.email == '%s' }.userId".formatted(TestUtils.TEST2_EMAIL));

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "role": "SUPER_ADMIN"
                        }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + test2UserId + "/role")
                .then()
                .statusCode(400);
    }

    @Test
    void testUpdateMemberRole_nonOwner_shouldReturn403() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Non Owner Role House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .extract()
                .path("inviteCode");

        String test2Token = TestUtils.loginAsTest2();
        joinAndAccept(accessToken, test2Token, inviteCode);

        String ownerUserId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .extract()
                .path("find { it.email == '%s' }.userId".formatted(TestUtils.DEMO_EMAIL));

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "role": "MEMBER"
                        }
                        """)
                .when()
                .put("/houses/" + houseId + "/members/" + ownerUserId + "/role")
                .then()
                .statusCode(403);
    }

    @Test
    void testDeleteHouse_nonOwner_shouldReturn403() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Delete Forbidden House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        String inviteCode = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .extract()
                .path("inviteCode");

        String test2Token = TestUtils.loginAsTest2();
        joinAndAccept(accessToken, test2Token, inviteCode);

        given()
                .header("Authorization", TestUtils.authHeader(test2Token))
                .when()
                .delete("/houses/" + houseId)
                .then()
                .statusCode(403);
    }

    @Test
    void testDeleteHouse_owner_shouldReturn204() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Delete Owner House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/houses/" + houseId)
                .then()
                .statusCode(204);
    }

    // ==================== ACTIVITY FEED ====================

    @Test
    void testGetHouseActivity_shouldReturn200() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/activity")
                .then()
                .statusCode(200)
                .body("$", isA(java.util.List.class));
    }

    @Test
    void testGetHouseActivity_withLimit_shouldReturn200() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .queryParam("limit", 5)
                .when()
                .get("/houses/" + houseId + "/activity")
                .then()
                .statusCode(200);
    }

    @Test
    void testGetHouseActivity_nonMember_shouldReturn403() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + UUID.randomUUID() + "/activity")
                .then()
                .statusCode(403);
    }

    @Test
    void testGetHouseActivity_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/houses/" + UUID.randomUUID() + "/activity")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetHouseActivity_afterCareAction_shouldShowActivity() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        UUID roomId = TestUtils.firstRoomId(accessToken);
        UUID plantId = TestUtils.createPlantAndReturnId(accessToken, roomId, "Activity Plant " + UUID.randomUUID());

        // Water the plant to create a care log
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(200);

        // Activity should include the watering
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/activity")
                .then()
                .statusCode(200)
                .body("size()", greaterThan(0));
    }

    // ==================== REMOVE MEMBER ====================

    @Test
    void testRemoveMember_selfRemove_shouldReturn400() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        // Get own user ID from token
        String myUserId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/auth/me")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/houses/" + houseId + "/members/" + myUserId)
                .then()
                .statusCode(400);
    }

    @Test
    void testRemoveMember_nonExistent_shouldReturn404() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/houses/" + houseId + "/members/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }

    @Test
    void testRemoveMember_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/houses/" + UUID.randomUUID() + "/members/" + UUID.randomUUID())
                .then()
                .statusCode(401);
    }

    // ==================== GET HOUSE BY ID ====================

    @Test
    void testGetHouseById_validHouse_shouldReturn200() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(200)
                .body("id", equalTo(houseId))
                .body("name", notNullValue())
                .body("inviteCode", notNullValue());
    }

    @Test
    void testGetHouseById_nonMember_shouldReturn403() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + UUID.randomUUID())
                .then()
                .statusCode(403);
    }

    // ==================== DELETE HOUSE WITH PLANTS ====================

    @Test
    void testDeleteHouse_withPlantsAndRooms_shouldCascadeDelete() {
        // Create a fresh house
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Cascade Delete House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Activate it
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .put("/houses/" + houseId + "/activate")
                .then()
                .statusCode(200);

        // Create a room
        String roomId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Delete Room",
                            "type": "LIVING_ROOM"
                        }
                        """)
                .when()
                .post("/rooms")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        // Create a plant in that room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "nickname": "Delete Plant",
                            "customSpecies": "Test species",
                            "roomId": "%s"
                        }
                        """.formatted(roomId))
                .when()
                .post("/plants")
                .then()
                .statusCode(201);

        // Delete the house
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/houses/" + houseId)
                .then()
                .statusCode(204);

        // Verify house is gone
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId)
                .then()
                .statusCode(403); // Not a member anymore (house deleted)
    }

    // ==================== DELETE HOUSE NON-EXISTENT ====================

    @Test
    void testDeleteHouse_nonExistent_shouldReturn403or404() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/houses/" + UUID.randomUUID())
                .then()
                .statusCode(anyOf(is(403), is(404)));
    }

    // ==================== UNAUTHENTICATED TESTS ====================

    @Test
    void testGetMyHouses_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/houses")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetActiveHouse_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/houses/active")
                .then()
                .statusCode(401);
    }

    @Test
    void testCreateHouse_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "name": "Unauth House"
                        }
                        """)
                .when()
                .post("/houses")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetHouseMembers_shouldReturn200() {
        String houseId = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/active")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + houseId + "/members")
                .then()
                .statusCode(200)
                .body("size()", greaterThan(0))
                .body("[0].userId", notNullValue())
                .body("[0].role", notNullValue());
    }

    @Test
    void testGetHouseMembers_nonMember_shouldReturn403() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/houses/" + UUID.randomUUID() + "/members")
                .then()
                .statusCode(403);
    }
}
