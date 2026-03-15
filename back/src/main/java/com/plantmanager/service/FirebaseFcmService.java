package com.plantmanager.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import com.plantmanager.entity.DeviceTokenEntity;
import com.plantmanager.entity.UserHouseEntity;
import io.quarkus.arc.properties.UnlessBuildProperty;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.io.FileInputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * JVM implementation backed by Firebase Cloud Messaging.
 */
@ApplicationScoped
@UnlessBuildProperty(name = "quarkus.native.enabled", stringValue = "true", enableIfMissing = true)
public class FirebaseFcmService extends FcmService {

    private static final Logger LOG = Logger.getLogger(FirebaseFcmService.class);

    @ConfigProperty(name = "firebase.credentials.path", defaultValue = "firebase-service-account.json")
    String credentialsPath;

    private boolean initialized = false;

    void onStart(@Observes StartupEvent ev) {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                InputStream classpathStream = getClass().getClassLoader().getResourceAsStream(credentialsPath);
                try (InputStream serviceAccount = classpathStream != null ? classpathStream : new FileInputStream(credentialsPath)) {
                    FirebaseOptions options = FirebaseOptions.builder()
                            .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                            .build();

                    FirebaseApp.initializeApp(options);
                    initialized = true;
                    LOG.info("Firebase Admin SDK initialized successfully");
                }
            } else {
                initialized = true;
            }
        } catch (Exception e) {
            LOG.warn("Firebase Admin SDK initialization failed (push notifications disabled): " + e.getMessage());
            initialized = false;
        }
    }

    @Override
    public void sendToHouseMembers(UUID houseId, UUID excludeUserId, String title, String body, Map<String, String> data) {
        if (!initialized) {
            LOG.debug("FCM not initialized, skipping push notification");
            return;
        }

        try {
            List<UserHouseEntity> members = UserHouseEntity.findByHouse(houseId);
            List<UUID> targetUserIds = members.stream()
                    .map(m -> m.user.id)
                    .filter(id -> !id.equals(excludeUserId))
                    .collect(Collectors.toList());

            if (targetUserIds.isEmpty()) {
                return;
            }

            List<DeviceTokenEntity> deviceTokens = DeviceTokenEntity.findByUsers(targetUserIds);
            if (deviceTokens.isEmpty()) {
                return;
            }

            List<String> tokens = deviceTokens.stream()
                    .map(dt -> dt.fcmToken)
                    .collect(Collectors.toList());

            sendToTokens(tokens, title, body, data);

        } catch (Exception e) {
            LOG.error("Failed to send push notification to house members", e);
        }
    }

    @Override
    public void sendToUser(UUID userId, String title, String body, Map<String, String> data) {
        if (!initialized) {
            return;
        }

        try {
            List<DeviceTokenEntity> deviceTokens = DeviceTokenEntity.findByUser(userId);
            if (deviceTokens.isEmpty()) {
                return;
            }

            List<String> tokens = deviceTokens.stream()
                    .map(dt -> dt.fcmToken)
                    .collect(Collectors.toList());

            sendToTokens(tokens, title, body, data);

        } catch (Exception e) {
            LOG.error("Failed to send push notification to user " + userId, e);
        }
    }

    private void sendToTokens(List<String> tokens, String title, String body, Map<String, String> data) {
        if (tokens.isEmpty()) {
            return;
        }

        List<Message> messages = new ArrayList<>();
        for (String token : tokens) {
            Message.Builder builder = Message.builder()
                    .setToken(token)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .setAndroidConfig(AndroidConfig.builder()
                            .setPriority(AndroidConfig.Priority.HIGH)
                            .setNotification(AndroidNotification.builder()
                                    .setClickAction("FLUTTER_NOTIFICATION_CLICK")
                                    .build())
                            .build());

            if (data != null && !data.isEmpty()) {
                builder.putAllData(data);
            }

            messages.add(builder.build());
        }

        try {
            BatchResponse response = FirebaseMessaging.getInstance().sendEach(messages);
            LOG.infof("FCM sent %d messages, %d successful, %d failed",
                    messages.size(), response.getSuccessCount(), response.getFailureCount());

            List<SendResponse> responses = response.getResponses();
            for (int i = 0; i < responses.size(); i++) {
                if (!responses.get(i).isSuccessful()) {
                    FirebaseMessagingException ex = responses.get(i).getException();
                    if (ex != null && (
                            ex.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED
                                    || ex.getMessagingErrorCode() == MessagingErrorCode.INVALID_ARGUMENT)) {
                        String staleToken = tokens.get(i);
                        DeviceTokenEntity.deleteByToken(staleToken);
                        LOG.infof("Removed stale FCM token: %s", staleToken.substring(0, 20) + "...");
                    }
                }
            }

        } catch (FirebaseMessagingException e) {
            LOG.error("Failed to send FCM batch", e);
        }
    }
}
