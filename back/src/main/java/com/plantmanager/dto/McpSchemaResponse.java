package com.plantmanager.dto;

import java.util.List;
import java.util.Map;

/**
 * Response DTO for the MCP schema endpoint.
 * Describes available tools for LLM integration (Goose/Mistral).
 */
public record McpSchemaResponse(
    String name,
    String version,
    List<ToolSchema> tools
) {
    public record ToolSchema(
        String name,
        String description,
        Map<String, ParameterSchema> parameters
    ) {}

    public record ParameterSchema(
        String type,
        boolean required,
        String description
    ) {}
}
