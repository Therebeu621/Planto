package com.plantmanager.dto;

/**
 * DTO for JWT token response after successful login.
 */
public record TokenResponse(
        String token,
        String type,
        long expiresIn) {
    /**
     * Create a Bearer token response.
     * 
     * @param token     the JWT token
     * @param expiresIn expiration time in seconds
     * @return TokenResponse with type "Bearer"
     */
    public static TokenResponse bearer(String token, long expiresIn) {
        return new TokenResponse(token, "Bearer", expiresIn);
    }
}
