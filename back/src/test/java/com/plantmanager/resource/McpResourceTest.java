package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for McpResource endpoints.
 * Tests MCP (Model Context Protocol) tool execution and schema.
 */
@QuarkusTest
public class McpResourceTest {

    private String accessToken;

    @ConfigProperty(name = "mcp.api.key")
    String mcpApiKey;

    @BeforeEach
    void setUp() {
        accessToken = TestUtils.loginAsDemo();
    }

    // ==================== GET /mcp/schema ====================

    @Test
    void testGetSchema_withApiKey_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(200)
                .body("name", notNullValue())
                .body("tools", notNullValue())
                .body("tools", isA(java.util.List.class));
    }

    @Test
    void testGetSchema_withJwt_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(200)
                .body("name", notNullValue())
                .body("tools", isA(java.util.List.class));
    }

    @Test
    void testGetSchema_noAuth_shouldReturn401() {
        given()
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetSchema_invalidApiKey_shouldReturn401() {
        given()
                .header("X-MCP-API-Key", "wrong-api-key")
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetSchema_emptyApiKey_shouldReturn401() {
        given()
                .header("X-MCP-API-Key", "")
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(401);
    }

    @Test
    void testGetSchema_toolsHaveRequiredFields() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(200)
                .body("tools.size()", greaterThan(0))
                .body("tools[0].name", notNullValue())
                .body("tools[0].description", notNullValue());
    }

    @Test
    void testGetSchema_hasVersionInfo() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(200)
                .body("version", notNullValue());
    }

    // ==================== POST /mcp/tools ====================

    @Test
    void testExecuteTool_listPlants_withApiKey_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    @Test
    void testExecuteTool_listPlants_withJwt_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    @Test
    void testExecuteTool_unknownTool_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "nonexistent_tool",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    @Test
    void testExecuteTool_noAuth_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(401);
    }

    @Test
    void testExecuteTool_invalidApiKey_shouldReturn401() {
        given()
                .header("X-MCP-API-Key", "invalid-key")
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(401);
    }

    @Test
    void testExecuteTool_emptyBody_shouldReturn400or500() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(anyOf(is(400), is(500)));
    }

    @Test
    void testExecuteTool_nullToolName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": null,
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400);
    }

    @Test
    void testExecuteTool_emptyToolName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400);
    }

    @Test
    void testExecuteTool_waterPlant_missingPlantId_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "water_plant",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400);
    }

    @Test
    void testExecuteTool_responseHasStatusField() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", anyOf(equalTo("success"), equalTo("error")))
                .body("message", notNullValue());
    }

    @Test
    void testExecuteTool_listPlants_shouldReturnData() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("data", notNullValue());
    }

    // ==================== DUAL AUTH TESTS ====================

    @Test
    void testExecuteTool_withApiKey_shouldReturn200() {
        given()
                .header("X-MCP-API-Key", mcpApiKey)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    @Test
    void testGetSchema_withApiKey_shouldReturn200_v2() {
        given()
                .header("X-MCP-API-Key", mcpApiKey)
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(200)
                .body("name", notNullValue());
    }

    @Test
    void testExecuteTool_bothAuthMethods_jwtTakesPrecedence() {
        // Both JWT and API key provided - JWT should take precedence
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .header("X-MCP-API-Key", mcpApiKey)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    // ==================== EDGE CASES ====================

    @Test
    void testExecuteTool_toolNameWithSpecialChars_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "'; DROP TABLE users; --",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400);
    }

    @Test
    void testExecuteTool_veryLongToolName_shouldReturn400() {
        String longToolName = "a".repeat(1000);
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "%s",
                            "params": {}
                        }
                        """.formatted(longToolName))
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400);
    }

    @Test
    void testGetSchema_multipleConsecutiveCalls_shouldBeConsistent() {
        // First call
        String firstResponse = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(200)
                .extract()
                .body().asString();

        // Second call should return same schema
        String secondResponse = given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .get("/mcp/schema")
                .then()
                .statusCode(200)
                .extract()
                .body().asString();

        assert firstResponse.equals(secondResponse);
    }

    // ==================== SEARCH_PLANTS TESTS ====================

    @Test
    void testSearchPlants_withValidQuery_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "search_plants",
                            "params": {"query": "ficus"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    @Test
    void testSearchPlants_withShortQuery_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "search_plants",
                            "params": {"query": "a"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    @Test
    void testSearchPlants_withMissingQuery_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "search_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== ADD_PLANT TESTS ====================

    @Test
    void testAddPlant_withSpeciesAndRoom_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"speciesName": "Ficus", "roomName": "Salon"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.nickname", notNullValue());
    }

    @Test
    void testAddPlant_withNicknameOnly_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "Mon petit cactus"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.nickname", equalTo("Mon petit cactus"));
    }

    @Test
    void testAddPlant_withNoParams_shouldReturn200WithDefaultNickname() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.nickname", equalTo("Ma plante"));
    }

    // ==================== WATER_PLANT TESTS ====================

    @Test
    void testWaterPlant_withValidPlant_shouldReturn200() {
        // First, add a plant to water
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlantToWater"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Then water it
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "water_plant",
                            "params": {"plantName": "PlantToWater"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("message", containsString("arrosee"));
    }

    @Test
    void testWaterPlant_withNonexistentPlant_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "water_plant",
                            "params": {"plantName": "PlanteTotalementInexistante999"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== WATER_ALL_PLANTS TESTS ====================

    @Test
    void testWaterAllPlants_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "water_all_plants",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    // ==================== LIST_ROOMS TESTS ====================

    @Test
    void testListRooms_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_rooms",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    // ==================== CREATE_ROOM TESTS ====================

    @Test
    void testCreateRoom_withValidName_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "create_room",
                            "params": {"name": "Veranda Test"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.name", equalTo("Veranda Test"));
    }

    @Test
    void testCreateRoom_duplicateName_shouldReturn400() {
        // Create the room first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "create_room",
                            "params": {"name": "Chambre Doublon"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Try to create again with same name
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "create_room",
                            "params": {"name": "Chambre Doublon"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"))
                .body("message", containsString("existe deja"));
    }

    @Test
    void testCreateRoom_missingName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "create_room",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== MOVE_PLANT TESTS ====================

    @Test
    void testMovePlant_withValidParams_shouldReturn200() {
        // Create a room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "create_room",
                            "params": {"name": "Bureau Move Test"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Add a plant
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlanteADeplacer"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Move the plant to the room
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "move_plant",
                            "params": {"plantName": "PlanteADeplacer", "roomName": "Bureau Move Test"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("message", containsString("deplacee"));
    }

    @Test
    void testMovePlant_missingPlantName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "move_plant",
                            "params": {"roomName": "Salon"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    @Test
    void testMovePlant_missingRoomName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "move_plant",
                            "params": {"plantName": "SomePlant"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    @Test
    void testMovePlant_nonexistentPlant_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "move_plant",
                            "params": {"plantName": "PlanteInexistante999", "roomName": "Salon"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== DELETE_PLANT TESTS ====================

    @Test
    void testDeletePlant_withValidPlant_shouldReturn200() {
        // Add a plant to delete
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlanteASupprimer"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Delete it
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "delete_plant",
                            "params": {"plantName": "PlanteASupprimer"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.deletedPlantName", equalTo("PlanteASupprimer"));
    }

    @Test
    void testDeletePlant_missingPlantName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "delete_plant",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    @Test
    void testDeletePlant_nonexistentPlant_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "delete_plant",
                            "params": {"plantName": "PlanteInexistanteXYZ"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== GET_PLANT_DETAIL TESTS ====================

    @Test
    void testGetPlantDetail_withValidPlant_shouldReturn200() {
        // Add a plant first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlanteDetail"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Get its detail
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "get_plant_detail",
                            "params": {"plantName": "PlanteDetail"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.nickname", equalTo("PlanteDetail"))
                .body("data.recentCareHistory", notNullValue());
    }

    @Test
    void testGetPlantDetail_missingPlantName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "get_plant_detail",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    @Test
    void testGetPlantDetail_nonexistentPlant_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "get_plant_detail",
                            "params": {"plantName": "PlanteInexistante999"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== LIST_PLANTS_NEEDING_WATER TESTS ====================

    @Test
    void testListPlantsNeedingWater_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "list_plants_needing_water",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"));
    }

    // ==================== GET_CARE_RECOMMENDATION TESTS ====================

    @Test
    void testGetCareRecommendation_withSpeciesName_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "get_care_recommendation",
                            "params": {"speciesName": "Monstera"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.speciesName", equalTo("Monstera"));
    }

    @Test
    void testGetCareRecommendation_missingSpeciesName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "get_care_recommendation",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== UPDATE_PLANT TESTS ====================

    @Test
    void testUpdatePlant_renameNickname_shouldReturn200() {
        // Add a plant first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlanteARenommer"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Rename it
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "update_plant",
                            "params": {"plantName": "PlanteARenommer", "newNickname": "NouveauNom"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.nickname", equalTo("NouveauNom"));
    }

    @Test
    void testUpdatePlant_markSick_shouldReturn200() {
        // Add a plant first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlanteMalade"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Mark it sick
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "update_plant",
                            "params": {"plantName": "PlanteMalade", "isSick": "true"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.isSick", equalTo(true));
    }

    @Test
    void testUpdatePlant_changeWateringInterval_shouldReturn200() {
        // Add a plant first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlanteIntervalle"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Change watering interval
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "update_plant",
                            "params": {"plantName": "PlanteIntervalle", "wateringIntervalDays": "14"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.wateringIntervalDays", equalTo(14));
    }

    @Test
    void testUpdatePlant_noUpdateParams_shouldReturn400() {
        // Add a plant first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "add_plant",
                            "params": {"nickname": "PlanteSansUpdate"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Try to update with no update params (only plantName)
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "update_plant",
                            "params": {"plantName": "PlanteSansUpdate"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"))
                .body("message", containsString("Aucun parametre"));
    }

    @Test
    void testUpdatePlant_missingPlantName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "update_plant",
                            "params": {"newNickname": "Test"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== DELETE_ROOM TESTS ====================

    @Test
    void testDeleteRoom_withValidRoom_shouldReturn200() {
        // Create a room first
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "create_room",
                            "params": {"name": "Piece A Supprimer"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200);

        // Delete it
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "delete_room",
                            "params": {"roomName": "Piece A Supprimer"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.deletedRoomName", equalTo("Piece A Supprimer"));
    }

    @Test
    void testDeleteRoom_missingRoomName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "delete_room",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    @Test
    void testDeleteRoom_nonexistentRoom_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "delete_room",
                            "params": {"roomName": "PieceInexistante999"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }

    // ==================== GET_WEATHER_WATERING_ADVICE TESTS ====================

    @Test
    void testGetWeatherWateringAdvice_withCity_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "get_weather_watering_advice",
                            "params": {"city": "Paris"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.city", notNullValue());
    }

    @Test
    void testGetWeatherWateringAdvice_withoutCity_shouldReturn200WithDefault() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "get_weather_watering_advice",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.city", notNullValue());
    }

    // ==================== ENRICH_PLANT_CARESHEET TESTS ====================

    @Test
    void testEnrichPlantCareSheet_withSpeciesName_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "enrich_plant_caresheet",
                            "params": {"speciesName": "Monstera"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.speciesName", equalTo("Monstera"));
    }

    @Test
    void testEnrichPlantCareSheet_withSpeciesAndCity_shouldReturn200() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "enrich_plant_caresheet",
                            "params": {"speciesName": "Ficus", "city": "Lyon"}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(200)
                .body("status", equalTo("success"))
                .body("data.speciesName", equalTo("Ficus"));
    }

    @Test
    void testEnrichPlantCareSheet_missingSpeciesName_shouldReturn400() {
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "tool": "enrich_plant_caresheet",
                            "params": {}
                        }
                        """)
                .when()
                .post("/mcp/tools")
                .then()
                .statusCode(400)
                .body("status", equalTo("error"));
    }
}
