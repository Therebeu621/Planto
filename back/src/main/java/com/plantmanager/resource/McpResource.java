package com.plantmanager.resource;

import java.util.Optional;

import com.plantmanager.dto.McpSchemaResponse;
import com.plantmanager.dto.McpToolRequest;
import com.plantmanager.dto.McpToolResponse;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.service.McpService;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jboss.logging.Logger;

import java.util.UUID;

/**
 * JAX-RS Resource for MCP (Model Context Protocol) endpoints.
 * Provides tool execution and schema endpoints for LLM integration (Goose/Mistral).
 *
 * Authentication: via X-MCP-API-Key header or standard Bearer JWT.
 */
@Path("/mcp")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "MCP", description = "Integration LLM via Goose/Mistral")
public class McpResource {

    private static final Logger LOG = Logger.getLogger(McpResource.class);

    @Inject
    McpService mcpService;

    @Inject
    JsonWebToken jwt;

    @ConfigProperty(name = "mcp.api.key")
    Optional<String> mcpApiKey;

    @ConfigProperty(name = "mcp.default.user.email")
    Optional<String> mcpDefaultUserEmail;

    /**
     * Execute an MCP tool.
     * Accepts tool name and parameters, executes the corresponding business logic,
     * and returns results in a format suitable for LLM consumption.
     *
     * @param apiKey  the MCP API key from X-MCP-API-Key header
     * @param request the tool execution request
     * @return tool execution result
     */
    @POST
    @Path("/tools")
    @Operation(summary = "Executer un outil MCP",
            description = "Endpoint pour l'integration LLM. Permet d'executer des outils metier via commandes naturelles.")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Outil execute avec succes"),
            @APIResponse(responseCode = "400", description = "Outil inconnu ou parametres invalides"),
            @APIResponse(responseCode = "401", description = "API Key MCP invalide")
    })
    public Response executeToolPost(
            @HeaderParam("X-MCP-API-Key") String apiKey,
            McpToolRequest request) {

        UUID userId = resolveUserId(apiKey);
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(McpToolResponse.error("Invalid or missing authentication. Provide X-MCP-API-Key header or Bearer JWT."))
                    .build();
        }

        McpToolResponse result = mcpService.executeTool(request, userId);

        int status = "error".equals(result.status()) ? 400 : 200;
        return Response.status(status).entity(result).build();
    }

    /**
     * Get the MCP tool schema.
     * Returns the list of available tools with their parameters.
     * Used by Goose/LLM tools to configure the integration.
     *
     * @param apiKey the MCP API key
     * @return schema describing available tools
     */
    @GET
    @Path("/schema")
    @Operation(summary = "Obtenir le schema des outils MCP",
            description = "Retourne la liste des outils disponibles avec leurs parametres pour la configuration Goose.")
    @APIResponses({
            @APIResponse(responseCode = "200", description = "Schema des outils MCP"),
            @APIResponse(responseCode = "401", description = "API Key MCP invalide")
    })
    public Response getSchema(@HeaderParam("X-MCP-API-Key") String apiKey) {
        // Schema is public info but we still validate auth
        if (!isAuthenticated(apiKey)) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(McpToolResponse.error("Invalid or missing authentication"))
                    .build();
        }

        McpSchemaResponse schema = mcpService.getSchema();
        return Response.ok(schema).build();
    }

    /**
     * Resolve the user ID from either MCP API key or JWT.
     * MCP API key maps to a default user; JWT uses the token subject.
     */
    private UUID resolveUserId(String apiKey) {
        // Try JWT first (standard bearer auth)
        if (jwt != null && jwt.getSubject() != null) {
            try {
                return UUID.fromString(jwt.getSubject());
            } catch (IllegalArgumentException ignored) {
            }
        }

        // Try MCP API key
        if (mcpApiKey.filter(key -> !key.isBlank()).isPresent() && apiKey != null && apiKey.equals(mcpApiKey.orElseThrow())) {
            // Resolve default MCP user
            if (mcpDefaultUserEmail.isPresent() && !mcpDefaultUserEmail.get().isBlank()) {
                return UserEntity.findByEmail(mcpDefaultUserEmail.get())
                        .map(u -> u.id)
                        .orElse(null);
            }
            // Fallback: use the first user in the system
            UserEntity firstUser = UserEntity.find("order by createdAt asc").firstResult();
            return firstUser != null ? firstUser.id : null;
        }

        return null;
    }

    /**
     * Check if the request is authenticated via API key or JWT.
     */
    private boolean isAuthenticated(String apiKey) {
        if (jwt != null && jwt.getSubject() != null) return true;
        return mcpApiKey.filter(key -> !key.isBlank()).isPresent() && apiKey != null && apiKey.equals(mcpApiKey.orElseThrow());
    }
}
