package com.plantmanager.security;

import com.plantmanager.entity.UserEntity;
import io.quarkus.test.junit.QuarkusTest;
import io.smallrye.jwt.auth.principal.JWTParser;
import jakarta.inject.Inject;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Tests for TokenUtils.
 */
@QuarkusTest
public class TokenUtilsTest {

    @Inject
    TokenUtils tokenUtils;

    @Inject
    JWTParser jwtParser;

    // ==================== EXPIRATION CONFIG ====================

    @Test
    void testGetAccessTokenExpiration_shouldReturnConfigured() {
        long expiration = tokenUtils.getAccessTokenExpiration();
        assertTrue(expiration > 0, "Access token expiration should be positive");
        assertEquals(3600, expiration);
    }

    @Test
    void testGetRefreshTokenExpiration_shouldReturnConfigured() {
        long expiration = tokenUtils.getRefreshTokenExpiration();
        assertTrue(expiration > 0, "Refresh token expiration should be positive");
        assertEquals(604800, expiration);
    }

    // ==================== TOKEN GENERATION ====================

    @Test
    void testGenerateAccessToken_shouldReturnNonNullToken() {
        UserEntity user = buildTestUser();
        String token = tokenUtils.generateAccessToken(user);
        assertNotNull(token);
        assertFalse(token.isBlank());
        assertEquals(3, token.split("\\.").length, "JWT should have 3 parts");
    }

    @Test
    void testGenerateRefreshToken_shouldReturnNonNullToken() {
        UserEntity user = buildTestUser();
        String token = tokenUtils.generateRefreshToken(user);
        assertNotNull(token);
        assertFalse(token.isBlank());
        assertEquals(3, token.split("\\.").length, "JWT should have 3 parts");
    }

    @Test
    @SuppressWarnings("deprecation")
    void testGenerateToken_deprecated_shouldReturnValidToken() {
        UserEntity user = buildTestUser();
        String token = tokenUtils.generateToken(user);
        assertNotNull(token);
        assertEquals(3, token.split("\\.").length, "Deprecated generateToken should return valid JWT");
    }

    // ==================== isRefreshToken ====================

    @Test
    void testIsRefreshToken_withRefreshToken_shouldReturnTrue() throws Exception {
        UserEntity user = buildTestUser();
        String refreshTokenStr = tokenUtils.generateRefreshToken(user);
        JsonWebToken jwt = jwtParser.parse(refreshTokenStr);
        assertTrue(tokenUtils.isRefreshToken(jwt), "Should return true for refresh token");
    }

    @Test
    void testIsRefreshToken_withAccessToken_shouldReturnFalse() throws Exception {
        UserEntity user = buildTestUser();
        String accessTokenStr = tokenUtils.generateAccessToken(user);
        JsonWebToken jwt = jwtParser.parse(accessTokenStr);
        assertFalse(tokenUtils.isRefreshToken(jwt), "Should return false for access token");
    }

    @Test
    void testIsRefreshToken_withMockedNullType_shouldReturnFalse() {
        JsonWebToken mockJwt = mock(JsonWebToken.class);
        when(mockJwt.getClaim("type")).thenReturn(null);
        assertFalse(tokenUtils.isRefreshToken(mockJwt), "Null claim should return false");
    }

    @Test
    void testIsRefreshToken_withMockedAccessType_shouldReturnFalse() {
        JsonWebToken mockJwt = mock(JsonWebToken.class);
        when(mockJwt.getClaim("type")).thenReturn("access");
        assertFalse(tokenUtils.isRefreshToken(mockJwt), "'access' type should return false");
    }

    // ==================== HELPER ====================

    private UserEntity buildTestUser() {
        UserEntity user = new UserEntity();
        user.id = UUID.randomUUID();
        user.email = "tokentest@example.com";
        user.displayName = "Token Tester";
        user.role = UserEntity.UserRole.MEMBER;
        return user;
    }
}
