package com.plantmanager.resource;

import com.plantmanager.dto.*;
import com.plantmanager.entity.CareLogEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.enums.CareAction;
import com.plantmanager.security.TokenUtils;
import com.plantmanager.service.EmailService;
import com.plantmanager.service.FileStorageService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.jboss.resteasy.reactive.multipart.FileUpload;
import org.jboss.resteasy.reactive.RestForm;
import org.mindrot.jbcrypt.BCrypt;

import java.io.FileInputStream;
import java.io.InputStream;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * JAX-RS Resource for authentication endpoints.
 * Provides register, login, refresh, forgot/reset password, email verification,
 * profile update, and protected user info endpoints.
 */
@Path("/auth")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AuthResource {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final String INVALID_TOKEN = "Invalid token";
    private static final String USER_NOT_FOUND = "User not found";
    private static final String INVALID_CODE = "Code invalide ou expire";

    @Inject
    TokenUtils tokenUtils;

    @Inject
    JsonWebToken jwt;

    @Inject
    io.smallrye.jwt.auth.principal.JWTParser jwtParser;

    @Inject
    FileStorageService fileStorageService;

    @Inject
    EmailService emailService;

    @ConfigProperty(name = "password.reset.expiration-minutes", defaultValue = "30")
    long passwordResetExpirationMinutes;

    @ConfigProperty(name = "email.verification.expiration-minutes", defaultValue = "15")
    long emailVerificationExpirationMinutes;

    // ==================== REGISTER / LOGIN ====================

    /**
     * Register a new user.
     * Sends a verification code by email.
     */
    @POST
    @Path("/register")
    @Transactional
    @PermitAll
    public Response register(@Valid RegisterDTO request) {
        if (UserEntity.existsByEmail(request.email())) {
            return Response.status(Response.Status.CONFLICT)
                    .entity(new ErrorResponse("Email already exists"))
                    .build();
        }

        UserEntity user = new UserEntity();
        user.email = request.email();
        user.passwordHash = BCrypt.hashpw(request.password(), BCrypt.gensalt(12));
        user.displayName = request.displayName();
        user.role = UserEntity.UserRole.MEMBER;
        user.emailVerified = false;

        // Generate email verification code
        String verificationCode = generateCode();
        user.emailVerificationCode = verificationCode;
        user.emailVerificationCodeExpiry = OffsetDateTime.now().plusMinutes(emailVerificationExpirationMinutes);

        user.persist();

        // Send verification email
        emailService.sendEmailVerificationCode(user.email, verificationCode);

        // Generate tokens (auto-login after registration)
        String accessToken = tokenUtils.generateAccessToken(user);
        String refreshToken = tokenUtils.generateRefreshToken(user);
        long expiresIn = tokenUtils.getAccessTokenExpiration();

        return Response.status(Response.Status.CREATED)
                .entity(AuthResponse.of(accessToken, refreshToken, expiresIn, UserResponse.from(user)))
                .build();
    }

    /**
     * Authenticate a user and return JWT tokens.
     */
    @POST
    @Path("/login")
    @PermitAll
    public Response login(@Valid LoginDTO request) {
        UserEntity user = UserEntity.findByEmail(request.email())
                .orElse(null);

        if (user == null || !BCrypt.checkpw(request.password(), user.passwordHash)) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse("Invalid email or password"))
                    .build();
        }

        String accessToken = tokenUtils.generateAccessToken(user);
        String refreshToken = tokenUtils.generateRefreshToken(user);
        long expiresIn = tokenUtils.getAccessTokenExpiration();

        return Response.ok(AuthResponse.of(accessToken, refreshToken, expiresIn, UserResponse.from(user))).build();
    }

    /**
     * Authenticate with Google.
     */
    @POST
    @Path("/google")
    @Transactional
    @PermitAll
    public Response loginWithGoogle(GoogleAuthRequest request) {
        try {
            String[] parts = request.idToken().split("\\.");
            if (parts.length != 3) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(new ErrorResponse("Invalid Google token format"))
                        .build();
            }

            String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
            com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.JsonNode json = mapper.readTree(payload);

            String email = json.has("email") ? json.get("email").asText() : null;
            String name = json.has("name") ? json.get("name").asText() : null;

            if (email == null || email.isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(new ErrorResponse("Email not found in Google token"))
                        .build();
            }

            UserEntity user = UserEntity.findByEmail(email).orElse(null);

            if (user == null) {
                user = new UserEntity();
                user.email = email;
                user.displayName = name != null ? name : email.split("@")[0];
                user.passwordHash = BCrypt.hashpw(UUID.randomUUID().toString(), BCrypt.gensalt(12));
                user.role = UserEntity.UserRole.MEMBER;
                user.emailVerified = true; // Google accounts are pre-verified
                user.persist();
            }

            String accessToken = tokenUtils.generateAccessToken(user);
            String refreshToken = tokenUtils.generateRefreshToken(user);
            long expiresIn = tokenUtils.getAccessTokenExpiration();

            return Response.ok(AuthResponse.of(accessToken, refreshToken, expiresIn, UserResponse.from(user))).build();

        } catch (Exception e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse("Failed to authenticate with Google: " + e.getMessage()))
                    .build();
        }
    }

    public record GoogleAuthRequest(String idToken) {
    }

    /**
     * Refresh the access token using a valid refresh token.
     */
    @POST
    @Path("/refresh")
    @PermitAll
    public Response refresh(@Valid RefreshTokenRequest request) {
        try {
            org.eclipse.microprofile.jwt.JsonWebToken refreshJwt = jwtParser.parse(request.refreshToken());

            Object tokenType = refreshJwt.getClaim("type");
            if (!"refresh".equals(tokenType)) {
                return Response.status(Response.Status.UNAUTHORIZED)
                        .entity(new ErrorResponse("Invalid token type. Expected refresh token."))
                        .build();
            }

            String userId = refreshJwt.getSubject();
            if (userId == null) {
                return Response.status(Response.Status.UNAUTHORIZED)
                        .entity(new ErrorResponse(INVALID_TOKEN))
                        .build();
            }

            UserEntity user = UserEntity.findById(UUID.fromString(userId));
            if (user == null) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity(new ErrorResponse(USER_NOT_FOUND))
                        .build();
            }

            String accessToken = tokenUtils.generateAccessToken(user);
            String refreshToken = tokenUtils.generateRefreshToken(user);
            long expiresIn = tokenUtils.getAccessTokenExpiration();

            return Response.ok(AuthResponse.of(accessToken, refreshToken, expiresIn, UserResponse.from(user))).build();

        } catch (Exception e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse("Invalid or expired refresh token"))
                    .build();
        }
    }

    // ==================== FORGOT / RESET PASSWORD ====================

    /**
     * Request a password reset. Sends a 6-digit code by email.
     */
    @POST
    @Path("/forgot-password")
    @Transactional
    @PermitAll
    public Response forgotPassword(@Valid ForgotPasswordDTO request) {
        UserEntity user = UserEntity.findByEmail(request.email()).orElse(null);

        // Always return 200 to prevent email enumeration
        if (user == null) {
            return Response.ok(new MessageResponse("Si cette adresse existe, un code de reinitialisation a ete envoye.")).build();
        }

        String resetCode = generateCode();
        user.passwordResetToken = resetCode;
        user.passwordResetTokenExpiry = OffsetDateTime.now().plusMinutes(passwordResetExpirationMinutes);
        user.persist();

        emailService.sendPasswordResetEmail(user.email, resetCode);

        return Response.ok(new MessageResponse("Si cette adresse existe, un code de reinitialisation a ete envoye.")).build();
    }

    /**
     * Reset password using the 6-digit code received by email.
     */
    @POST
    @Path("/reset-password")
    @Transactional
    @PermitAll
    public Response resetPassword(@Valid ResetPasswordDTO request) {
        UserEntity user = UserEntity.findByEmail(request.email()).orElse(null);

        if (user == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse(INVALID_CODE))
                    .build();
        }

        if (user.passwordResetToken == null
                || !user.passwordResetToken.equals(request.code())
                || user.passwordResetTokenExpiry == null
                || user.passwordResetTokenExpiry.isBefore(OffsetDateTime.now())) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse(INVALID_CODE))
                    .build();
        }

        user.passwordHash = BCrypt.hashpw(request.newPassword(), BCrypt.gensalt(12));
        user.passwordResetToken = null;
        user.passwordResetTokenExpiry = null;
        user.persist();

        return Response.ok(new MessageResponse("Mot de passe reinitialise avec succes")).build();
    }

    // ==================== EMAIL VERIFICATION ====================

    /**
     * Verify email with the 6-digit code.
     */
    @POST
    @Path("/verify-email")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response verifyEmail(@Valid VerifyEmailDTO request) {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UserEntity user = UserEntity.findById(UUID.fromString(userId));
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        if (user.emailVerified) {
            return Response.ok(new MessageResponse("Email deja verifie")).build();
        }

        if (user.emailVerificationCode == null
                || !user.emailVerificationCode.equals(request.code())
                || user.emailVerificationCodeExpiry == null
                || user.emailVerificationCodeExpiry.isBefore(OffsetDateTime.now())) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse(INVALID_CODE))
                    .build();
        }

        user.emailVerified = true;
        user.emailVerificationCode = null;
        user.emailVerificationCodeExpiry = null;
        user.persist();

        return Response.ok(UserResponse.from(user)).build();
    }

    /**
     * Resend email verification code.
     */
    @POST
    @Path("/resend-verification")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response resendVerification() {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UserEntity user = UserEntity.findById(UUID.fromString(userId));
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        if (user.emailVerified) {
            return Response.ok(new MessageResponse("Email deja verifie")).build();
        }

        String code = generateCode();
        user.emailVerificationCode = code;
        user.emailVerificationCodeExpiry = OffsetDateTime.now().plusMinutes(emailVerificationExpirationMinutes);
        user.persist();

        emailService.sendEmailVerificationCode(user.email, code);

        return Response.ok(new MessageResponse("Code de verification envoye")).build();
    }

    // ==================== PROFILE ====================

    /**
     * Get current user details.
     */
    @GET
    @Path("/me")
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response me() {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UserEntity user = UserEntity.findById(UUID.fromString(userId));
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        return Response.ok(UserResponse.from(user)).build();
    }

    /**
     * Update the current user's profile (displayName).
     */
    @PUT
    @Path("/me")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response updateProfile(@Valid UpdateProfileDTO request) {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UserEntity user = UserEntity.findById(UUID.fromString(userId));
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        if (request.displayName() != null) {
            user.displayName = request.displayName();
        }

        user.persist();

        return Response.ok(UserResponse.from(user)).build();
    }

    /**
     * Change the current user's password.
     */
    @PUT
    @Path("/me/password")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response changePassword(@Valid ChangePasswordDTO request) {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UserEntity user = UserEntity.findById(UUID.fromString(userId));
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        if (!BCrypt.checkpw(request.currentPassword(), user.passwordHash)) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("Mot de passe actuel incorrect"))
                    .build();
        }

        user.passwordHash = BCrypt.hashpw(request.newPassword(), BCrypt.gensalt(12));
        user.persist();

        return Response.ok(new MessageResponse("Mot de passe modifie avec succes")).build();
    }

    /**
     * Get user statistics.
     */
    @GET
    @Path("/me/stats")
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response getMyStats() {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UUID userUuid = UUID.fromString(userId);

        List<UserPlantEntity> plants = UserPlantEntity.findByUser(userUuid);
        int totalPlants = plants.size();

        long healthyCount = plants.stream()
                .filter(p -> !p.isSick && !p.isWilted && !p.needsRepotting)
                .count();
        int healthyPercentage = totalPlants > 0 ? (int) ((healthyCount * 100) / totalPlants) : 100;

        String oldestPlantName = null;
        OffsetDateTime oldestPlantAcquiredAt = null;
        UserPlantEntity oldestPlant = plants.stream()
                .filter(p -> p.acquiredAt != null)
                .min(Comparator.comparing(p -> p.acquiredAt))
                .orElse(null);
        if (oldestPlant != null) {
            oldestPlantName = oldestPlant.nickname;
            oldestPlantAcquiredAt = oldestPlant.acquiredAt.atStartOfDay().atOffset(java.time.ZoneOffset.UTC);
        }

        YearMonth currentMonth = YearMonth.now();
        OffsetDateTime startOfMonth = currentMonth.atDay(1).atStartOfDay().atOffset(java.time.ZoneOffset.UTC);
        long wateringsThisMonth = CareLogEntity.count(
                "user.id = ?1 and action = ?2 and performedAt >= ?3",
                userUuid, CareAction.WATERING, startOfMonth);

        int wateringStreak = calculateWateringStreak(userUuid);

        return Response.ok(UserStatsDTO.of(
                totalPlants,
                (int) wateringsThisMonth,
                wateringStreak,
                healthyPercentage,
                oldestPlantName,
                oldestPlantAcquiredAt)).build();
    }

    private int calculateWateringStreak(UUID userId) {
        List<CareLogEntity> wateringLogs = CareLogEntity.list(
                "user.id = ?1 and action = ?2 order by performedAt desc",
                userId, CareAction.WATERING);

        if (wateringLogs.isEmpty()) {
            return 0;
        }

        int streak = 0;
        OffsetDateTime today = OffsetDateTime.now().truncatedTo(ChronoUnit.DAYS);
        OffsetDateTime expectedDay = today;

        for (CareLogEntity log : wateringLogs) {
            OffsetDateTime logDay = log.performedAt.truncatedTo(ChronoUnit.DAYS);

            if (logDay.equals(expectedDay)) {
                streak++;
                expectedDay = expectedDay.minusDays(1);
            } else if (logDay.isBefore(expectedDay)) {
                long daysDiff = ChronoUnit.DAYS.between(logDay, expectedDay);
                if (daysDiff > 1) {
                    break;
                }
                streak++;
                expectedDay = logDay.minusDays(1);
            }
        }

        return streak;
    }

    // ==================== PROFILE PHOTO ====================

    @POST
    @Path("/me/photo")
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response uploadProfilePhoto(@RestForm("file") FileUpload file) {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UUID userUuid = UUID.fromString(userId);
        UserEntity user = UserEntity.findById(userUuid);
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        if (file == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("No file provided"))
                    .build();
        }

        try {
            if (user.profilePhotoPath != null) {
                fileStorageService.deleteFile(user.profilePhotoPath);
            }

            String relativePath;
            try (InputStream fis = new FileInputStream(file.uploadedFile().toFile())) {
                relativePath = fileStorageService.storeProfilePhoto(
                        userUuid,
                        fis,
                        file.fileName(),
                        file.contentType()
                );
            }

            user.profilePhotoPath = relativePath;
            user.persist();

            return Response.ok(UserResponse.from(user)).build();

        } catch (IllegalArgumentException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse(e.getMessage()))
                    .build();
        } catch (Exception e) {
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("Erreur lors de l'upload: " + e.getMessage()))
                    .build();
        }
    }

    @DELETE
    @Path("/me/photo")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response deleteProfilePhoto() {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UUID userUuid = UUID.fromString(userId);
        UserEntity user = UserEntity.findById(userUuid);
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        if (user.profilePhotoPath != null) {
            fileStorageService.deleteFile(user.profilePhotoPath);
            user.profilePhotoPath = null;
            user.persist();
        }

        return Response.ok(UserResponse.from(user)).build();
    }

    // ==================== ACCOUNT DELETION ====================

    @DELETE
    @Path("/me")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response deleteAccount() {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UUID userUuid = UUID.fromString(userId);
        UserEntity user = UserEntity.findById(userUuid);
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        if (user.profilePhotoPath != null) {
            fileStorageService.deleteFile(user.profilePhotoPath);
        }

        List<UserPlantEntity> plants = UserPlantEntity.findByUser(userUuid);
        for (UserPlantEntity plant : plants) {
            CareLogEntity.delete("plant.id = ?1", plant.id);
            com.plantmanager.entity.NotificationEntity.delete("plant.id = ?1", plant.id);
            plant.delete();
        }

        com.plantmanager.entity.NotificationEntity.delete("user.id = ?1", userUuid);
        CareLogEntity.delete("user.id = ?1", userUuid);

        List<com.plantmanager.entity.UserHouseEntity> memberships =
                com.plantmanager.entity.UserHouseEntity.findByUser(userUuid);
        for (com.plantmanager.entity.UserHouseEntity membership : memberships) {
            membership.delete();
        }

        user.delete();

        return Response.noContent().build();
    }

    // ==================== DEVICE TOKEN (FCM) ====================

    @POST
    @Path("/device-token")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response registerDeviceToken(@Valid RegisterDeviceTokenDTO request) {
        String userId = jwt.getSubject();
        if (userId == null) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(new ErrorResponse(INVALID_TOKEN))
                    .build();
        }

        UUID userUuid = UUID.fromString(userId);
        UserEntity user = UserEntity.findById(userUuid);
        if (user == null) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity(new ErrorResponse(USER_NOT_FOUND))
                    .build();
        }

        com.plantmanager.entity.DeviceTokenEntity existing =
                com.plantmanager.entity.DeviceTokenEntity.findByToken(request.fcmToken());

        if (existing != null) {
            existing.user = user;
            existing.deviceInfo = request.deviceInfo();
            existing.persist();
        } else {
            com.plantmanager.entity.DeviceTokenEntity deviceToken = new com.plantmanager.entity.DeviceTokenEntity();
            deviceToken.user = user;
            deviceToken.fcmToken = request.fcmToken();
            deviceToken.deviceInfo = request.deviceInfo();
            deviceToken.persist();
        }

        return Response.ok().build();
    }

    @DELETE
    @Path("/device-token")
    @Transactional
    @RolesAllowed({ "MEMBER", "OWNER", "GUEST" })
    public Response unregisterDeviceToken(RegisterDeviceTokenDTO request) {
        if (request != null && request.fcmToken() != null) {
            com.plantmanager.entity.DeviceTokenEntity.deleteByToken(request.fcmToken());
        }
        return Response.noContent().build();
    }

    // ==================== HELPERS ====================

    private String generateCode() {
        SecureRandom secureRandom = new SecureRandom();
        int code = 100000 + secureRandom.nextInt(900000);
        return String.valueOf(code);
    }

}
