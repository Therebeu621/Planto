package com.plantmanager.resource;

import com.plantmanager.service.FileStorageService;
import jakarta.annotation.security.PermitAll;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.io.IOException;
import java.nio.file.Files;

/**
 * Resource for serving uploaded files.
 */
@Path("/files")
public class FileResource {

    @Inject
    FileStorageService fileStorageService;

    /**
     * Serve a file from storage.
     * URL format: /api/v1/files/avatars/filename.jpg
     *
     * @param folder   the folder (e.g., "avatars", "plants")
     * @param filename the filename
     * @return the file content
     */
    @GET
    @Path("/{folder}/{filename}")
    @PermitAll
    public Response getFile(
            @PathParam("folder") String folder,
            @PathParam("filename") String filename) {

        // Security: prevent path traversal attacks
        if (folder.contains("..") || filename.contains("..")) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("Invalid path")
                    .build();
        }

        String relativePath = folder + java.io.File.separator + filename;
        java.nio.file.Path filePath = fileStorageService.getAbsolutePath(relativePath);

        if (!Files.exists(filePath)) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("File not found")
                    .build();
        }

        try {
            byte[] fileContent = Files.readAllBytes(filePath);
            String contentType = Files.probeContentType(filePath);
            if (contentType == null) {
                contentType = MediaType.APPLICATION_OCTET_STREAM;
            }

            return Response.ok(fileContent)
                    .type(contentType)
                    .header("Cache-Control", "public, max-age=86400") // Cache for 1 day
                    .build();

        } catch (IOException e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("Error reading file")
                    .build();
        }
    }
}
