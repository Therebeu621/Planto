package com.plantmanager.dto;

/**
 * Response DTO for MCP tool execution.
 * Matches the OpenAPI McpToolResponse schema.
 */
public record McpToolResponse(
    String status,
    String message,
    Object data
) {
    public static McpToolResponse success(String message, Object data) {
        return new McpToolResponse("success", message, data);
    }

    public static McpToolResponse error(String message) {
        return new McpToolResponse("error", message, null);
    }
}
