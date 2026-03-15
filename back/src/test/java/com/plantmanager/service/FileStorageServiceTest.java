package com.plantmanager.service;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
public class FileStorageServiceTest {

    @Inject
    FileStorageService fileStorageService;

    private Path testDir;

    @BeforeEach
    void setUp() throws IOException {
        testDir = Path.of("target/test-photos");
        Files.createDirectories(testDir);
    }

    @AfterEach
    void tearDown() throws IOException {
        // Clean up test files
        if (Files.exists(testDir.resolve("avatars"))) {
            Files.walk(testDir.resolve("avatars"))
                    .sorted(java.util.Comparator.reverseOrder())
                    .forEach(p -> { try { Files.deleteIfExists(p); } catch (IOException ignored) {} });
        }
        if (Files.exists(testDir.resolve("plants"))) {
            Files.walk(testDir.resolve("plants"))
                    .sorted(java.util.Comparator.reverseOrder())
                    .forEach(p -> { try { Files.deleteIfExists(p); } catch (IOException ignored) {} });
        }
    }

    // ===== storeProfilePhoto tests =====

    @Test
    void testStoreProfilePhoto_validJpeg_shouldSucceed() throws IOException {
        UUID userId = UUID.randomUUID();
        byte[] imageData = new byte[1024]; // 1KB fake image
        InputStream is = new ByteArrayInputStream(imageData);

        String result = fileStorageService.storeProfilePhoto(userId, is, "photo.jpg", "image/jpeg");

        assertNotNull(result);
        assertTrue(result.startsWith("avatars/"));
        assertTrue(result.endsWith(".jpg"));
        assertTrue(result.contains(userId.toString()));

        // Verify file exists on disk
        Path storedFile = Path.of("target/test-photos", result);
        assertTrue(Files.exists(storedFile));
    }

    @Test
    void testStoreProfilePhoto_validPng_shouldSucceed() throws IOException {
        UUID userId = UUID.randomUUID();
        byte[] imageData = new byte[512];
        InputStream is = new ByteArrayInputStream(imageData);

        String result = fileStorageService.storeProfilePhoto(userId, is, "photo.png", "image/png");

        assertNotNull(result);
        assertTrue(result.endsWith(".png"));
    }

    @Test
    void testStoreProfilePhoto_validWebp_shouldSucceed() throws IOException {
        UUID userId = UUID.randomUUID();
        byte[] imageData = new byte[512];
        InputStream is = new ByteArrayInputStream(imageData);

        String result = fileStorageService.storeProfilePhoto(userId, is, "photo.webp", "image/webp");

        assertNotNull(result);
        assertTrue(result.endsWith(".webp"));
    }

    @Test
    void testStoreProfilePhoto_validGif_shouldSucceed() throws IOException {
        UUID userId = UUID.randomUUID();
        byte[] imageData = new byte[512];
        InputStream is = new ByteArrayInputStream(imageData);

        String result = fileStorageService.storeProfilePhoto(userId, is, "photo.gif", "image/gif");

        assertNotNull(result);
        assertTrue(result.endsWith(".gif"));
    }

    @Test
    void testStoreProfilePhoto_invalidContentType_shouldThrow() {
        UUID userId = UUID.randomUUID();
        byte[] data = new byte[100];
        InputStream is = new ByteArrayInputStream(data);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                fileStorageService.storeProfilePhoto(userId, is, "file.pdf", "application/pdf"));

        assertTrue(ex.getMessage().contains("Type de fichier non autorise"));
    }

    @Test
    void testStoreProfilePhoto_invalidExtension_shouldThrow() {
        UUID userId = UUID.randomUUID();
        byte[] data = new byte[100];
        InputStream is = new ByteArrayInputStream(data);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                fileStorageService.storeProfilePhoto(userId, is, "file.bmp", "image/jpeg"));

        assertTrue(ex.getMessage().contains("Extension de fichier non autorisee"));
    }

    @Test
    void testStoreProfilePhoto_tooLarge_shouldThrow() {
        UUID userId = UUID.randomUUID();
        // 6MB file exceeds 5MB limit
        byte[] data = new byte[6 * 1024 * 1024];
        InputStream is = new ByteArrayInputStream(data);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                fileStorageService.storeProfilePhoto(userId, is, "large.jpg", "image/jpeg"));

        assertTrue(ex.getMessage().contains("Fichier trop volumineux"));
    }

    @Test
    void testStoreProfilePhoto_noExtension_shouldDefaultToJpg() throws IOException {
        UUID userId = UUID.randomUUID();
        byte[] imageData = new byte[512];
        InputStream is = new ByteArrayInputStream(imageData);

        String result = fileStorageService.storeProfilePhoto(userId, is, "photo", "image/jpeg");

        assertNotNull(result);
        assertTrue(result.endsWith(".jpg"));
    }

    @Test
    void testStoreProfilePhoto_nullFileName_shouldDefaultToJpg() throws IOException {
        UUID userId = UUID.randomUUID();
        byte[] imageData = new byte[512];
        InputStream is = new ByteArrayInputStream(imageData);

        String result = fileStorageService.storeProfilePhoto(userId, is, null, "image/jpeg");

        assertNotNull(result);
        assertTrue(result.endsWith(".jpg"));
    }

    // ===== storePlantPhoto tests =====

    @Test
    void testStorePlantPhoto_validJpeg_shouldSucceed() throws IOException {
        UUID plantId = UUID.randomUUID();
        byte[] imageData = new byte[1024];
        InputStream is = new ByteArrayInputStream(imageData);

        String result = fileStorageService.storePlantPhoto(plantId, is, "plant.jpg", "image/jpeg");

        assertNotNull(result);
        assertTrue(result.startsWith("plants/"));
        assertTrue(result.contains(plantId.toString()));
    }

    @Test
    void testStorePlantPhoto_invalidContentType_shouldThrow() {
        UUID plantId = UUID.randomUUID();
        byte[] data = new byte[100];
        InputStream is = new ByteArrayInputStream(data);

        assertThrows(IllegalArgumentException.class, () ->
                fileStorageService.storePlantPhoto(plantId, is, "file.txt", "text/plain"));
    }

    @Test
    void testStorePlantPhoto_invalidExtension_shouldThrow() {
        UUID plantId = UUID.randomUUID();
        byte[] data = new byte[100];
        InputStream is = new ByteArrayInputStream(data);

        assertThrows(IllegalArgumentException.class, () ->
                fileStorageService.storePlantPhoto(plantId, is, "file.svg", "image/jpeg"));
    }

    @Test
    void testStorePlantPhoto_tooLarge_shouldThrow() {
        UUID plantId = UUID.randomUUID();
        byte[] data = new byte[6 * 1024 * 1024];
        InputStream is = new ByteArrayInputStream(data);

        assertThrows(IllegalArgumentException.class, () ->
                fileStorageService.storePlantPhoto(plantId, is, "big.jpg", "image/jpeg"));
    }

    // ===== deleteFile tests =====

    @Test
    void testDeleteFile_existingFile_shouldReturnTrue() throws IOException {
        // Create a file first
        UUID userId = UUID.randomUUID();
        byte[] data = new byte[100];
        String path = fileStorageService.storeProfilePhoto(userId, new ByteArrayInputStream(data), "test.jpg", "image/jpeg");

        boolean deleted = fileStorageService.deleteFile(path);
        assertTrue(deleted);

        // Verify file is gone
        assertFalse(Files.exists(Path.of("target/test-photos", path)));
    }

    @Test
    void testDeleteFile_nonExistentFile_shouldReturnFalse() {
        boolean deleted = fileStorageService.deleteFile("nonexistent/file.jpg");
        assertFalse(deleted);
    }

    @Test
    void testDeleteFile_nullPath_shouldReturnFalse() {
        assertFalse(fileStorageService.deleteFile(null));
    }

    @Test
    void testDeleteFile_blankPath_shouldReturnFalse() {
        assertFalse(fileStorageService.deleteFile("   "));
    }

    // ===== getFileUrl tests =====

    @Test
    void testGetFileUrl_validPath_shouldReturnUrl() {
        String url = fileStorageService.getFileUrl("avatars/photo.jpg");
        assertEquals("/files/avatars/photo.jpg", url);
    }

    @Test
    void testGetFileUrl_nullPath_shouldReturnNull() {
        assertNull(fileStorageService.getFileUrl(null));
    }

    @Test
    void testGetFileUrl_blankPath_shouldReturnNull() {
        assertNull(fileStorageService.getFileUrl("   "));
    }

    // ===== getAbsolutePath tests =====

    @Test
    void testGetAbsolutePath_shouldReturnCorrectPath() {
        Path path = fileStorageService.getAbsolutePath("avatars/photo.jpg");
        assertNotNull(path);
        assertTrue(path.toString().contains("avatars"));
        assertTrue(path.toString().contains("photo.jpg"));
    }
}
