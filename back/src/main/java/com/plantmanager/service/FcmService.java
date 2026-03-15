package com.plantmanager.service;

import io.quarkus.arc.properties.IfBuildProperty;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.Map;
import java.util.UUID;

/**
 * Native-image friendly fallback that keeps the notification API injectable
 * even when Firebase is disabled for the build.
 */
@ApplicationScoped
@IfBuildProperty(name = "quarkus.native.enabled", stringValue = "true")
public class FcmService {

    public void sendToHouseMembers(UUID houseId, UUID excludeUserId, String title, String body, Map<String, String> data) {
        // Firebase Admin SDK is disabled for native builds.
    }

    public void sendToUser(UUID userId, String title, String body, Map<String, String> data) {
        // Firebase Admin SDK is disabled for native builds.
    }
}
