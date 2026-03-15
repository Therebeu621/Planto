package com.plantmanager.service;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Set;
import java.util.UUID;

/**
 * Service for handling file storage operations.
 * Stores files on the local filesystem.
 */
@ApplicationScoped
public class FileStorageService {

    private static final Logger LOG = Logger.getLogger(FileStorageService.class);

    private static final Set<String> ALLOWED_IMAGE_TYPES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/gif"
    );

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of(
            ".jpg", ".jpeg", ".png", ".webp", ".gif"
    );

    @ConfigProperty(name = "plant.photos.storage-path", defaultValue = "/app/photos")
    String storagePath;

    @ConfigProperty(name = "plant.photos.max-size-mb", defaultValue = "5")
    int maxSizeMb;

    /**
     * Store a profile photo for a user.
     *
     * @param userId      the user's UUID
     * @param inputStream the file input stream
     * @param fileName    the original file name
     * @param contentType the file's content type
     * @return the relative path where the file was stored
     * @throws IOException if storage fails
     */
    public String storeProfilePhoto(UUID userId, InputStream inputStream, String fileName, String contentType)
            throws IOException {
        // Validate content type
        if (!ALLOWED_IMAGE_TYPES.contains(contentType)) {
            throw new IllegalArgumentException("Type de fichier non autorise. Utilisez JPG, PNG, WebP ou GIF.");
        }

        // Get file extension
        String extension = getExtension(fileName);
        if (!ALLOWED_EXTENSIONS.contains(extension.toLowerCase())) {
            throw new IllegalArgumentException("Extension de fichier non autorisee.");
        }

        // Create directory structure: /storage/avatars/
        Path avatarsDir = Paths.get(storagePath, "avatars");
        Files.createDirectories(avatarsDir);

        // Generate unique filename: userId-timestamp.ext
        String uniqueFileName = userId.toString() + "-" + System.currentTimeMillis() + extension;
        Path targetPath = avatarsDir.resolve(uniqueFileName);

        // Copy file to storage
        Files.copy(inputStream, targetPath, StandardCopyOption.REPLACE_EXISTING);

        // Verify file size after copy
        long fileSizeBytes = Files.size(targetPath);
        long maxSizeBytes = (long) maxSizeMb * 1024 * 1024;
        if (fileSizeBytes > maxSizeBytes) {
            Files.deleteIfExists(targetPath);
            throw new IllegalArgumentException("Fichier trop volumineux. Maximum: " + maxSizeMb + " MB");
        }

        LOG.infof("Stored profile photo for user %s at %s", userId, targetPath);

        // Return relative path for database storage
        return "avatars/" + uniqueFileName;
    }

    /**
     * Store a photo for a plant.
     *
     * @param plantId     the plant's UUID
     * @param inputStream the file input stream
     * @param fileName    the original file name
     * @param contentType the file's content type
     * @return the relative path where the file was stored
     * @throws IOException if storage fails
     */
    public String storePlantPhoto(UUID plantId, InputStream inputStream, String fileName, String contentType)
            throws IOException {
        // Validate content type
        if (!ALLOWED_IMAGE_TYPES.contains(contentType)) {
            throw new IllegalArgumentException("Type de fichier non autorise. Utilisez JPG, PNG, WebP ou GIF.");
        }

        // Get file extension
        String extension = getExtension(fileName);
        if (!ALLOWED_EXTENSIONS.contains(extension.toLowerCase())) {
            throw new IllegalArgumentException("Extension de fichier non autorisee.");
        }

        // Create directory structure: /storage/plants/
        Path plantsDir = Paths.get(storagePath, "plants");
        Files.createDirectories(plantsDir);

        // Generate unique filename: plantId-timestamp.ext
        String uniqueFileName = plantId.toString() + "-" + System.currentTimeMillis() + extension;
        Path targetPath = plantsDir.resolve(uniqueFileName);

        // Copy file to storage
        Files.copy(inputStream, targetPath, StandardCopyOption.REPLACE_EXISTING);

        // Verify file size after copy
        long fileSizeBytes = Files.size(targetPath);
        long maxSizeBytes = (long) maxSizeMb * 1024 * 1024;
        if (fileSizeBytes > maxSizeBytes) {
            Files.deleteIfExists(targetPath);
            throw new IllegalArgumentException("Fichier trop volumineux. Maximum: " + maxSizeMb + " MB");
        }

        LOG.infof("Stored plant photo for plant %s at %s", plantId, targetPath);

        // Return relative path for database storage
        return "plants/" + uniqueFileName;
    }

    /**
     * Delete a file from storage.
     *
     * @param relativePath the relative path of the file to delete
     * @return true if file was deleted, false if it didn't exist
     */
    public boolean deleteFile(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            return false;
        }

        try {
            Path filePath = Paths.get(storagePath, relativePath);
            boolean deleted = Files.deleteIfExists(filePath);
            if (deleted) {
                LOG.infof("Deleted file: %s", filePath);
            }
            return deleted;
        } catch (IOException e) {
            LOG.errorf("Failed to delete file %s: %s", relativePath, e.getMessage());
            return false;
        }
    }

    /**
     * Get the full URL path for serving a file.
     *
     * @param relativePath the relative path stored in database
     * @return the full URL path or null if no path
     */
    public String getFileUrl(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            return null;
        }
        return "/files/" + relativePath;
    }

    /**
     * Get the absolute path for a file.
     *
     * @param relativePath the relative path
     * @return the absolute Path object
     */
    public Path getAbsolutePath(String relativePath) {
        return Paths.get(storagePath, relativePath);
    }

    private String getExtension(String fileName) {
        if (fileName == null || !fileName.contains(".")) {
            return ".jpg"; // Default extension
        }
        return fileName.substring(fileName.lastIndexOf("."));
    }
}
