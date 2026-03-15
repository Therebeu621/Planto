package com.plantmanager.dto;

import java.util.Map;

/**
 * Request DTO for MCP tool execution.
 * Matches the OpenAPI McpToolRequest schema.
 */
public record McpToolRequest(
    String tool,
    Map<String, String> params
) {
    public String param(String key) {
        return params != null ? params.get(key) : null;
    }
}
