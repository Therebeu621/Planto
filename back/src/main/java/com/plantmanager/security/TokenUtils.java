package com.plantmanager.security;

import com.plantmanager.entity.UserEntity;
import io.smallrye.jwt.build.Jwt;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.jwt.JsonWebToken;

import java.time.Duration;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;

/**
 * Utility class for generating and validating JWT tokens.
 * Uses SmallRye JWT for token creation with RSA signing.
 */
@ApplicationScoped
public class TokenUtils {

    @ConfigProperty(name = "smallrye.jwt.new-token.issuer", defaultValue = "plant-management")
    String issuer;

    @ConfigProperty(name = "jwt.access-token.expiration", defaultValue = "3600")
    long accessTokenExpiration;

    @ConfigProperty(name = "jwt.refresh-token.expiration", defaultValue = "604800")
    long refreshTokenExpiration;

    /**
     * Generate a signed JWT access token for the given user.
     * 
     * @param user the authenticated user
     * @return signed JWT access token string
     */
    public String generateAccessToken(UserEntity user) {
        Instant now = Instant.now();
        Instant expiry = now.plus(Duration.ofSeconds(accessTokenExpiration));

        return Jwt.issuer(issuer)
                .upn(user.email)
                .subject(user.id.toString())
                .groups(Set.of(user.role.name()))
                .claim("displayName", user.displayName)
                .claim("type", "access")
                .issuedAt(now)
                .expiresAt(expiry)
                .sign();
    }

    /**
     * Generate a signed JWT refresh token for the given user.
     * Refresh tokens have longer lifespan and are used to obtain new access tokens.
     * 
     * @param user the authenticated user
     * @return signed JWT refresh token string
     */
    public String generateRefreshToken(UserEntity user) {
        Instant now = Instant.now();
        Instant expiry = now.plus(Duration.ofSeconds(refreshTokenExpiration));

        return Jwt.issuer(issuer)
                .upn(user.email)
                .subject(user.id.toString())
                .groups(Set.of(user.role.name()))
                .claim("type", "refresh")
                .claim("jti", UUID.randomUUID().toString())
                .issuedAt(now)
                .expiresAt(expiry)
                .sign();
    }

    /**
     * Legacy method for backward compatibility.
     * @deprecated Use generateAccessToken instead.
     */
    @Deprecated
    public String generateToken(UserEntity user) {
        return generateAccessToken(user);
    }

    /**
     * Check if the given JWT is a refresh token.
     * 
     * @param jwt the token to check
     * @return true if it's a refresh token
     */
    public boolean isRefreshToken(JsonWebToken jwt) {
        Object type = jwt.getClaim("type");
        return "refresh".equals(type);
    }

    /**
     * Get the access token expiration time in seconds.
     * 
     * @return expiration time in seconds
     */
    public long getAccessTokenExpiration() {
        return accessTokenExpiration;
    }

    /**
     * Get the refresh token expiration time in seconds.
     * 
     * @return expiration time in seconds
     */
    public long getRefreshTokenExpiration() {
        return refreshTokenExpiration;
    }
}
