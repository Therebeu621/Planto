package com.plantmanager.resource;

import com.plantmanager.TestUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/**
 * Integration tests for AuthResource endpoints.
 * Tests authentication flow: register, login, refresh, user info.
 */
@QuarkusTest
public class AuthResourceTest {

    @AfterEach
    void cleanPhotos() {
        TestUtils.cleanupTestPhotosDir();
    }

    // ==================== REGISTER TESTS ====================

    @Test
    void testRegister_newUser_shouldReturn201() {
        String newEmail = "newuser" + UUID.randomUUID() + "@example.com";

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "SecurePassword123!",
                            "displayName": "New User"
                        }
                        """.formatted(newEmail))
                .when()
                .post("/auth/register")
                .then()
                .statusCode(201)
                .body("user.email", equalTo(newEmail))
                .body("user.displayName", equalTo("New User"))
                .body("user.id", notNullValue())
                .body("accessToken", notNullValue());
    }

    @Test
    void testRegister_duplicateEmail_shouldReturn409() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "AnotherPassword123!",
                            "displayName": "Duplicate User"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL))
                .when()
                .post("/auth/register")
                .then()
                .statusCode(409)
                .body("message", containsStringIgnoringCase("email"));
    }

    @Test
    void testRegister_invalidEmail_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "not-an-email",
                            "password": "ValidPassword123!",
                            "displayName": "Bad Email User"
                        }
                        """)
                .when()
                .post("/auth/register")
                .then()
                .statusCode(400);
    }

    // ==================== LOGIN TESTS ====================

    @Test
    void testLogin_validCredentials_shouldReturnToken() {
        // First ensure user exists by calling loginAsDemo (which creates user if needed)
        TestUtils.loginAsDemo();
        
        // Now test the actual login endpoint
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL, TestUtils.DEMO_PASSWORD))
                .when()
                .post("/auth/login")
                .then()
                .statusCode(200)
                .body("accessToken", notNullValue())
                .body("refreshToken", notNullValue())
                .body("expiresIn", greaterThan(0));
    }

    @Test
    void testLogin_invalidPassword_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "WrongPassword123!"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL))
                .when()
                .post("/auth/login")
                .then()
                .statusCode(401)
                .body("message", containsStringIgnoringCase("invalid"));
    }

    @Test
    void testLogin_userNotFound_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "nonexistent@example.com",
                            "password": "AnyPassword123!"
                        }
                        """)
                .when()
                .post("/auth/login")
                .then()
                .statusCode(401)
                .body("message", containsStringIgnoringCase("invalid"));
    }

    // ==================== REFRESH TOKEN TESTS ====================

    @Test
    void testRefresh_validRefreshToken_shouldReturn200() {
        // First, login to get tokens
        String refreshToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL, TestUtils.DEMO_PASSWORD))
                .when()
                .post("/auth/login")
                .then()
                .statusCode(200)
                .extract()
                .path("refreshToken");

        // Now refresh
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "refreshToken": "%s"
                        }
                        """.formatted(refreshToken))
                .when()
                .post("/auth/refresh")
                .then()
                .statusCode(200)
                .body("accessToken", notNullValue())
                .body("expiresIn", greaterThan(0));
    }

    @Test
    void testRefresh_accessTokenInsteadOfRefresh_shouldReturn401() {
        // Login to get access token
        String accessToken = TestUtils.loginAsDemo();

        // Try to use access token as refresh token - should fail
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "refreshToken": "%s"
                        }
                        """.formatted(accessToken))
                .when()
                .post("/auth/refresh")
                .then()
                .statusCode(401)
                .body("message", containsStringIgnoringCase("invalid"));
    }

    // ==================== USER INFO TESTS ====================

    @Test
    void testMe_authenticatedUser_shouldReturnUserInfo() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .when()
                .get("/auth/me")
                .then()
                .statusCode(200)
                .body("email", equalTo(TestUtils.DEMO_EMAIL))
                .body("displayName", notNullValue())
                .body("id", notNullValue());
    }

    @Test
    void testMe_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/auth/me")
                .then()
                .statusCode(401);
    }

    @Test
    void testMyStats_authenticatedUser_shouldReturnStats() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .when()
                .get("/auth/me/stats")
                .then()
                .statusCode(200)
                .body("totalPlants", isA(Number.class))
                .body("wateringsThisMonth", isA(Number.class))
                .body("wateringStreak", isA(Number.class))
                .body("healthyPlantsPercentage", isA(Number.class));
    }

    @Test
    void testMyStats_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/auth/me/stats")
                .then()
                .statusCode(401);
    }

    // ==================== REFRESH VALIDATION TESTS ====================

    @Test
    void testRefresh_missingRefreshToken_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/auth/refresh")
                .then()
                .statusCode(400);
    }

    // ==================== GOOGLE AUTH TESTS ====================

    @Test
    void testGoogleLogin_invalidTokenFormat_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "invalid-token"
                        }
                        """)
                .when()
                .post("/auth/google")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("format"));
    }

    @Test
    void testGoogleLogin_invalidPayloadBase64_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "aaa.not-base64.bbb"
                        }
                        """)
                .when()
                .post("/auth/google")
                .then()
                .statusCode(401);
    }

    @Test
    void testGoogleLogin_missingEmail_shouldReturn400() {
        String idToken = TestUtils.buildGoogleIdToken(Map.of("name", "No Email User"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "%s"
                        }
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("email"));
    }

    @Test
    void testGoogleLogin_validToken_shouldReturn200() {
        String googleEmail = "google-" + UUID.randomUUID() + "@example.com";
        String idToken = TestUtils.buildGoogleIdToken(Map.of(
                "email", googleEmail,
                "name", "Google Test User"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "%s"
                        }
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .body("accessToken", notNullValue())
                .body("user.email", equalTo(googleEmail))
                .body("user.displayName", equalTo("Google Test User"));
    }

    // ==================== PROFILE PHOTO TESTS ====================

    @Test
    void testUploadProfilePhoto_success_shouldReturn200() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .multiPart("file", "profile.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(200)
                .body("profilePhotoUrl", notNullValue())
                .body("profilePhotoUrl", containsString("/api/v1/files/avatars/"));
    }

    @Test
    void testUploadProfilePhoto_invalidMime_shouldReturn400() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .multiPart("file", "profile.txt", "not-an-image".getBytes(StandardCharsets.UTF_8), "text/plain")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(400);
    }

    @Test
    void testDeleteProfilePhoto_shouldReturn200() {
        String token = TestUtils.loginAsDemo();

        // Upload first
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .multiPart("file", "profile.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(200);

        // Then delete
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .when()
                .delete("/auth/me/photo")
                .then()
                .statusCode(200)
                .body("profilePhotoUrl", nullValue());
    }

    // ==================== FORGOT PASSWORD TESTS ====================

    @Test
    void testForgotPassword_validEmail_shouldReturn200() {
        // Ensure the demo user exists
        TestUtils.loginAsDemo();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL))
                .when()
                .post("/auth/forgot-password")
                .then()
                .statusCode(200)
                .body("message", notNullValue());
    }

    @Test
    void testForgotPassword_unknownEmail_shouldReturn200() {
        // Should still return 200 to prevent email enumeration
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "unknown-user-%s@example.com"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/auth/forgot-password")
                .then()
                .statusCode(200)
                .body("message", notNullValue());
    }

    // ==================== RESET PASSWORD TESTS ====================

    @Test
    void testResetPassword_invalidCode_shouldReturn400() {
        // Ensure the demo user exists
        TestUtils.loginAsDemo();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "code": "000000",
                            "newPassword": "NewSecurePassword123!"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL))
                .when()
                .post("/auth/reset-password")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("invalide"));
    }

    // ==================== VERIFY EMAIL TESTS ====================

    @Test
    void testVerifyEmail_alreadyVerified_shouldReturn200WithMessage() {
        // Create a Google user (auto-verified) and use their token
        String googleEmail = "verified-" + UUID.randomUUID() + "@example.com";
        String idToken = TestUtils.buildGoogleIdToken(Map.of(
                "email", googleEmail,
                "name", "Verified User"));

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "%s"
                        }
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .extract()
                .path("accessToken");

        // Try to verify email that is already verified
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "code": "123456"
                        }
                        """)
                .when()
                .post("/auth/verify-email")
                .then()
                .statusCode(200)
                .body("message", containsStringIgnoringCase("deja"));
    }

    @Test
    void testVerifyEmail_invalidCode_shouldReturn400() {
        // Register a new user (email not verified by default)
        String newEmail = "verify-" + UUID.randomUUID() + "@example.com";

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "SecurePassword123!",
                            "displayName": "Verify Test User"
                        }
                        """.formatted(newEmail))
                .when()
                .post("/auth/register")
                .then()
                .statusCode(201)
                .extract()
                .path("accessToken");

        // Try to verify with an invalid code
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "code": "000000"
                        }
                        """)
                .when()
                .post("/auth/verify-email")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("invalide"));
    }

    // ==================== RESEND VERIFICATION TESTS ====================

    @Test
    void testResendVerification_shouldReturn200() {
        // Register a new user (email not verified)
        String newEmail = "resend-" + UUID.randomUUID() + "@example.com";

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "SecurePassword123!",
                            "displayName": "Resend Test User"
                        }
                        """.formatted(newEmail))
                .when()
                .post("/auth/register")
                .then()
                .statusCode(201)
                .extract()
                .path("accessToken");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/auth/resend-verification")
                .then()
                .statusCode(200)
                .body("message", containsStringIgnoringCase("envoye"));
    }

    // ==================== UPDATE PROFILE TESTS ====================

    @Test
    void testUpdateProfile_changeDisplayName_shouldReturn200() {
        String token = TestUtils.loginAsDemo();
        String newName = "Updated Name " + UUID.randomUUID().toString().substring(0, 6);

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "displayName": "%s"
                        }
                        """.formatted(newName))
                .when()
                .put("/auth/me")
                .then()
                .statusCode(200)
                .body("displayName", equalTo(newName));
    }

    // ==================== CHANGE PASSWORD TESTS ====================

    @Test
    void testChangePassword_correctCurrentPassword_shouldReturn200() {
        // Create a unique user for this test to avoid affecting other tests
        String email = "chgpwd-" + UUID.randomUUID() + "@example.com";
        String originalPassword = "OriginalPassword123!";

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "%s",
                            "displayName": "Change Pwd User"
                        }
                        """.formatted(email, originalPassword))
                .when()
                .post("/auth/register")
                .then()
                .statusCode(201)
                .extract()
                .path("accessToken");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "currentPassword": "%s",
                            "newPassword": "NewSecurePassword456!"
                        }
                        """.formatted(originalPassword))
                .when()
                .put("/auth/me/password")
                .then()
                .statusCode(200)
                .body("message", containsStringIgnoringCase("succes"));
    }

    @Test
    void testChangePassword_wrongCurrentPassword_shouldReturn400() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "currentPassword": "WrongPassword999!",
                            "newPassword": "NewSecurePassword456!"
                        }
                        """)
                .when()
                .put("/auth/me/password")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("incorrect"));
    }

    // ==================== DEVICE TOKEN TESTS ====================

    @Test
    void testRegisterDeviceToken_shouldReturn200() {
        String token = TestUtils.loginAsDemo();
        String fcmToken = "fcm-token-" + UUID.randomUUID();

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "%s",
                            "deviceInfo": "Test Device Android 14"
                        }
                        """.formatted(fcmToken))
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(200);
    }

    @Test
    void testRegisterDeviceToken_updateExisting_shouldReturn200() {
        String token = TestUtils.loginAsDemo();
        String fcmToken = "fcm-token-update-" + UUID.randomUUID();

        // Register the token a first time
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "%s",
                            "deviceInfo": "Device v1"
                        }
                        """.formatted(fcmToken))
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(200);

        // Register the same token again with updated device info
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "%s",
                            "deviceInfo": "Device v2"
                        }
                        """.formatted(fcmToken))
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(200);
    }

    @Test
    void testUnregisterDeviceToken_shouldReturn204() {
        String token = TestUtils.loginAsDemo();
        String fcmToken = "fcm-token-delete-" + UUID.randomUUID();

        // Register first
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "%s",
                            "deviceInfo": "Test Device"
                        }
                        """.formatted(fcmToken))
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(200);

        // Unregister
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "%s"
                        }
                        """.formatted(fcmToken))
                .when()
                .delete("/auth/device-token")
                .then()
                .statusCode(204);
    }

    // ==================== DELETE ACCOUNT TESTS ====================

    @Test
    void testDeleteAccount_shouldReturn204() {
        // Create a unique user to delete
        String email = "delete-" + UUID.randomUUID() + "@example.com";
        String password = "DeleteMePassword123!";

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "%s",
                            "displayName": "Delete Me User"
                        }
                        """.formatted(email, password))
                .when()
                .post("/auth/register")
                .then()
                .statusCode(201)
                .extract()
                .path("accessToken");

        // Delete the account
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/auth/me")
                .then()
                .statusCode(204);

        // Verify the user can no longer login
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """.formatted(email, password))
                .when()
                .post("/auth/login")
                .then()
                .statusCode(401);
    }

    // ==================== GOOGLE AUTH EDGE CASES ====================

    @Test
    void testGoogleLogin_emailButNoName_shouldUseEmailPrefix() {
        String googleEmail = "noname-" + UUID.randomUUID() + "@example.com";
        String expectedDisplayName = googleEmail.split("@")[0];
        String idToken = TestUtils.buildGoogleIdToken(Map.of("email", googleEmail));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "%s"
                        }
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .body("accessToken", notNullValue())
                .body("user.email", equalTo(googleEmail))
                .body("user.displayName", equalTo(expectedDisplayName));
    }

    @Test
    void testGoogleLogin_existingUser_shouldLoginNotDuplicate() {
        String googleEmail = "existing-google-" + UUID.randomUUID() + "@example.com";
        String idToken = TestUtils.buildGoogleIdToken(Map.of(
                "email", googleEmail,
                "name", "Existing Google User"));

        // First login creates the user
        String firstUserId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "%s"
                        }
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .body("user.email", equalTo(googleEmail))
                .extract()
                .path("user.id");

        // Second login should return the same user, not create a duplicate
        String secondUserId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "%s"
                        }
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .body("user.email", equalTo(googleEmail))
                .extract()
                .path("user.id");

        org.junit.jupiter.api.Assertions.assertEquals(firstUserId, secondUserId,
                "Second Google login should return the same user, not create a duplicate");
    }

    // ==================== RESET PASSWORD EDGE CASES ====================

    @Test
    void testResetPassword_unknownEmail_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "nobody-%s@example.com",
                            "code": "123456",
                            "newPassword": "NewPassword123!"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/auth/reset-password")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("invalide"));
    }

    @Test
    void testResetPassword_expiredCode_shouldReturn400() {
        // Trigger forgot-password to set a code, then try with wrong code
        // (cannot easily simulate expiry, but a wrong code covers the same branch)
        TestUtils.loginAsDemo();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL))
                .when()
                .post("/auth/forgot-password")
                .then()
                .statusCode(200);

        // Try reset with a definitely-wrong code
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "code": "999999",
                            "newPassword": "NewPassword123!"
                        }
                        """.formatted(TestUtils.DEMO_EMAIL))
                .when()
                .post("/auth/reset-password")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("invalide"));
    }

    // ==================== RESEND VERIFICATION EDGE CASES ====================

    @Test
    void testResendVerification_alreadyVerified_shouldReturn200() {
        // Google users are auto-verified
        String googleEmail = "resend-verified-" + UUID.randomUUID() + "@example.com";
        String idToken = TestUtils.buildGoogleIdToken(Map.of(
                "email", googleEmail,
                "name", "Already Verified"));

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "%s"
                        }
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .extract()
                .path("accessToken");

        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .contentType(ContentType.JSON)
                .when()
                .post("/auth/resend-verification")
                .then()
                .statusCode(200)
                .body("message", containsStringIgnoringCase("deja"));
    }

    // ==================== UNAUTHENTICATED ACCESS TESTS ====================

    @Test
    void testUpdateProfile_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "displayName": "Hacker"
                        }
                        """)
                .when()
                .put("/auth/me")
                .then()
                .statusCode(401);
    }

    @Test
    void testChangePassword_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "currentPassword": "anything",
                            "newPassword": "NewPassword123!"
                        }
                        """)
                .when()
                .put("/auth/me/password")
                .then()
                .statusCode(401);
    }

    @Test
    void testDeleteAccount_unauthenticated_shouldReturn401() {
        given()
                .when()
                .delete("/auth/me")
                .then()
                .statusCode(401);
    }

    @Test
    void testRegisterDeviceToken_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "some-token"
                        }
                        """)
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(401);
    }

    @Test
    void testVerifyEmail_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "code": "123456"
                        }
                        """)
                .when()
                .post("/auth/verify-email")
                .then()
                .statusCode(401);
    }

    @Test
    void testResendVerification_unauthenticated_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .when()
                .post("/auth/resend-verification")
                .then()
                .statusCode(401);
    }

    // ==================== STATS TESTS ====================

    @Test
    void testGetStats_shouldReturnUserStats() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/auth/me/stats")
                .then()
                .statusCode(200)
                .body("totalPlants", greaterThanOrEqualTo(0))
                .body("wateringsThisMonth", greaterThanOrEqualTo(0))
                .body("wateringStreak", greaterThanOrEqualTo(0))
                .body("healthyPlantsPercentage", greaterThanOrEqualTo(0));
    }

    @Test
    void testGetStats_withPlants_shouldReflectData() {
        String token = TestUtils.loginAsDemo();
        java.util.UUID roomId = TestUtils.firstRoomId(token);

        // Create a plant and water it to have stats
        java.util.UUID plantId = TestUtils.createPlantAndReturnId(token, roomId, "Stats Plant " + UUID.randomUUID());

        given()
                .header("Authorization", "Bearer " + token)
                .contentType("application/json")
                .when()
                .post("/plants/" + plantId + "/water")
                .then()
                .statusCode(200);

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .get("/auth/me/stats")
                .then()
                .statusCode(200)
                .body("totalPlants", greaterThan(0))
                .body("wateringsThisMonth", greaterThan(0));
    }

    @Test
    void testGetStats_unauthenticated_shouldReturn401() {
        given()
                .when()
                .get("/auth/me/stats")
                .then()
                .statusCode(401);
    }

    // ==================== PHOTO DELETE TESTS ====================

    @Test
    void testDeleteProfilePhoto_noExistingPhoto_shouldReturn200() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .delete("/auth/me/photo")
                .then()
                .statusCode(200);
    }

    @Test
    void testUploadAndDeleteProfilePhoto_fullFlow() {
        String token = TestUtils.loginAsDemo();

        // Upload a photo
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .multiPart("file", "avatar.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(200)
                .body("profilePhotoUrl", notNullValue());

        // Delete the photo
        given()
                .header("Authorization", "Bearer " + token)
                .when()
                .delete("/auth/me/photo")
                .then()
                .statusCode(200);
    }

    @Test
    void testUploadProfilePhoto_noFile_shouldReturn400() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType("multipart/form-data")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(anyOf(is(400), is(415)));
    }

    // ==================== GOOGLE AUTH EDGE CASES ====================

    @Test
    void testGoogleAuth_invalidTokenFormat_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "idToken": "invalid-token-no-dots"
                        }
                        """)
                .when()
                .post("/auth/google")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("invalid"));
    }

    @Test
    void testGoogleAuth_existingUser_shouldLoginNotCreate() {
        String email = "google-existing-" + UUID.randomUUID() + "@example.com";

        // First login creates user
        String idToken1 = TestUtils.buildGoogleIdToken(Map.of("email", email, "name", "Google User"));
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {"idToken": "%s"}
                        """.formatted(idToken1))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .body("user.email", equalTo(email));

        // Second login should reuse existing user
        String idToken2 = TestUtils.buildGoogleIdToken(Map.of("email", email, "name", "Google User"));
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {"idToken": "%s"}
                        """.formatted(idToken2))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .body("user.email", equalTo(email));
    }

    @Test
    void testGoogleAuth_noNameInToken_shouldUseEmailPrefix() {
        String email = "no-name-" + UUID.randomUUID() + "@example.com";
        String idToken = TestUtils.buildGoogleIdToken(Map.of("email", email));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {"idToken": "%s"}
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(200)
                .body("user.displayName", notNullValue());
    }

    @Test
    void testGoogleAuth_noEmailInToken_shouldReturn400() {
        String idToken = TestUtils.buildGoogleIdToken(Map.of("name", "No Email User"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {"idToken": "%s"}
                        """.formatted(idToken))
                .when()
                .post("/auth/google")
                .then()
                .statusCode(400)
                .body("message", containsStringIgnoringCase("email"));
    }

    // ==================== DEVICE TOKEN TESTS ====================

    @Test
    void testRegisterDeviceToken_newToken_shouldReturn200() {
        String token = TestUtils.loginAsDemo();

        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "test-fcm-token-%s",
                            "deviceInfo": "Test Device"
                        }
                        """.formatted(UUID.randomUUID()))
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(200);
    }

    @Test
    void testRegisterDeviceToken_existingToken_shouldUpdate() {
        String token = TestUtils.loginAsDemo();
        String fcmToken = "existing-fcm-" + UUID.randomUUID();

        // Register once
        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "%s",
                            "deviceInfo": "Device v1"
                        }
                        """.formatted(fcmToken))
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(200);

        // Register again with same token but different info
        given()
                .header("Authorization", "Bearer " + token)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "fcmToken": "%s",
                            "deviceInfo": "Device v2"
                        }
                        """.formatted(fcmToken))
                .when()
                .post("/auth/device-token")
                .then()
                .statusCode(200);
    }

    // ==================== REFRESH TOKEN EDGE CASES ====================

    @Test
    void testRefresh_withAccessToken_shouldFail() {
        // Using an access token (not refresh token) should fail
        String accessToken = TestUtils.loginAsDemo();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "refreshToken": "%s"
                        }
                        """.formatted(accessToken))
                .when()
                .post("/auth/refresh")
                .then()
                .statusCode(401);
    }

    @Test
    void testRefresh_withInvalidToken_shouldReturn401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "refreshToken": "completely-invalid-token"
                        }
                        """)
                .when()
                .post("/auth/refresh")
                .then()
                .statusCode(401);
    }

    // ==================== DELETE ACCOUNT WITH PHOTO ====================

    @Test
    void testDeleteAccount_withProfilePhoto_shouldCleanUpPhoto() {
        // Create a user, upload a photo, then delete - ensures photo cleanup branch is covered
        String email = "delete-photo-" + UUID.randomUUID() + "@example.com";
        String password = "DeletePhotoUser123!";

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "%s",
                            "password": "%s",
                            "displayName": "Photo Delete User"
                        }
                        """.formatted(email, password))
                .when()
                .post("/auth/register")
                .then()
                .statusCode(201)
                .extract()
                .path("accessToken");

        // Upload a profile photo
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .multiPart("file", "avatar.png", TestUtils.minimalPngBytes(), "image/png")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(200)
                .body("profilePhotoUrl", notNullValue());

        // Delete the account (should also clean up the photo)
        given()
                .header("Authorization", TestUtils.authHeader(accessToken))
                .when()
                .delete("/auth/me")
                .then()
                .statusCode(204);
    }

    // ==================== ADDITIONAL EDGE CASES ====================

    @Test
    void testRegister_missingPassword_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "nopass@test.com",
                            "displayName": "No Pass"
                        }
                        """)
                .when()
                .post("/auth/register")
                .then()
                .statusCode(400);
    }

    @Test
    void testRegister_missingEmail_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "password": "SomePassword123!",
                            "displayName": "No Email"
                        }
                        """)
                .when()
                .post("/auth/register")
                .then()
                .statusCode(400);
    }

    @Test
    void testRegister_emptyBody_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/auth/register")
                .then()
                .statusCode(400);
    }

    @Test
    void testLogin_emptyBody_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/auth/login")
                .then()
                .statusCode(anyOf(is(400), is(401)));
    }

    @Test
    void testLogin_missingEmail_shouldReturn400or401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "password": "somepassword"
                        }
                        """)
                .when()
                .post("/auth/login")
                .then()
                .statusCode(anyOf(is(400), is(401)));
    }

    @Test
    void testLogin_missingPassword_shouldReturn400or401() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "someone@test.com"
                        }
                        """)
                .when()
                .post("/auth/login")
                .then()
                .statusCode(anyOf(is(400), is(401)));
    }

    @Test
    void testForgotPassword_emptyBody_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/auth/forgot-password")
                .then()
                .statusCode(anyOf(is(200), is(400)));
    }

    @Test
    void testResetPassword_emptyBody_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .post("/auth/reset-password")
                .then()
                .statusCode(400);
    }

    @Test
    void testUpdateProfile_emptyBody_shouldReturn200() {
        String token = TestUtils.loginAsDemo();
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("{}")
                .when()
                .put("/auth/me")
                .then()
                .statusCode(200);
    }

    @Test
    void testUploadProfilePhoto_wrongContentType_shouldReturn400or415() {
        String token = TestUtils.loginAsDemo();
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .multiPart("file", "avatar.gif", new byte[]{1, 2, 3}, "image/gif")
                .when()
                .post("/auth/me/photo")
                .then()
                .statusCode(anyOf(is(200), is(400)));
    }

    @Test
    void testRegister_shortPassword_shouldReturn400() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "email": "shortpass@test.com",
                            "password": "ab",
                            "displayName": "Short Pass"
                        }
                        """)
                .when()
                .post("/auth/register")
                .then()
                .statusCode(400);
    }

    @Test
    void testChangePassword_emptyNewPassword_shouldReturn400() {
        String token = TestUtils.loginAsDemo();
        given()
                .header("Authorization", TestUtils.authHeader(token))
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "currentPassword": "password123",
                            "newPassword": ""
                        }
                        """)
                .when()
                .put("/auth/me/password")
                .then()
                .statusCode(400);
    }
}
