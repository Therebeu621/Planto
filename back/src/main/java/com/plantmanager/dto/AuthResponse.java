package com.plantmanager.dto;

/**
 * DTO for authentication response after login/register.
 * Conforms to OpenAPI contract AuthResponse schema.
 */
public record AuthResponse(
        String accessToken,
        String refreshToken,
        long expiresIn,
        UserResponse user) {

    /**
     * Create an AuthResponse with tokens and user info.
     *
     * @param accessToken  the JWT access token
     * @param refreshToken the JWT refresh token
     * @param expiresIn    access token expiration in seconds
     * @param user         the authenticated user details
     * @return AuthResponse
     */
    public static AuthResponse of(String accessToken, String refreshToken, long expiresIn, UserResponse user) {
        return new AuthResponse(accessToken, refreshToken, expiresIn, user);
    }
}
