package com.plantmanager.resource;

import com.plantmanager.dto.ErrorResponse;
import jakarta.validation.ConstraintViolationException;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.logging.Logger;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;

public class GlobalExceptionMapper {

    private static final Logger LOG = Logger.getLogger(GlobalExceptionMapper.class);

    @ServerExceptionMapper
    public Response mapConstraintViolationException(ConstraintViolationException e) {
        String message = e.getConstraintViolations().stream()
                .map(v -> v.getMessage())
                .distinct()
                .reduce((a, b) -> a + "; " + b)
                .orElse("Erreur de validation");
        return Response.status(Response.Status.BAD_REQUEST)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse(message))
                .build();
    }

    @ServerExceptionMapper
    public Response mapNotFoundException(NotFoundException e) {
        return Response.status(Response.Status.NOT_FOUND)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse(e.getMessage() != null ? e.getMessage() : "Resource not found"))
                .build();
    }

    @ServerExceptionMapper
    public Response mapForbiddenException(ForbiddenException e) {
        return Response.status(Response.Status.FORBIDDEN)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse(e.getMessage() != null ? e.getMessage() : "Access denied"))
                .build();
    }

    @ServerExceptionMapper
    public Response mapBadRequestException(BadRequestException e) {
        return Response.status(Response.Status.BAD_REQUEST)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse(e.getMessage() != null ? e.getMessage() : "Invalid request"))
                .build();
    }

    @ServerExceptionMapper
    public Response mapIllegalArgumentException(IllegalArgumentException e) {
        return Response.status(Response.Status.BAD_REQUEST)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse(e.getMessage() != null ? e.getMessage() : "Invalid argument"))
                .build();
    }

    @ServerExceptionMapper
    public Response mapWebApplicationException(WebApplicationException e) {
        int status = e.getResponse().getStatus();
        return Response.status(status)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse(e.getMessage() != null ? e.getMessage() : "Error"))
                .build();
    }

    @ServerExceptionMapper
    public Response mapGenericException(Exception e) {
        LOG.error("Unhandled exception", e);
        return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .type(MediaType.APPLICATION_JSON)
                .entity(new ErrorResponse("Internal server error"))
                .build();
    }
}
