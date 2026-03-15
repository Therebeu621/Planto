package com.plantmanager.service;

import com.plantmanager.entity.HouseEntity;
import com.plantmanager.entity.RoomEntity;
import com.plantmanager.entity.UserEntity;
import com.plantmanager.entity.UserHouseEntity;
import com.plantmanager.entity.UserPlantEntity;
import com.plantmanager.entity.enums.Exposure;
import com.plantmanager.entity.enums.RoomType;
import io.quarkus.arc.profile.IfBuildProfile;
import io.quarkus.logging.Log;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import org.mindrot.jbcrypt.BCrypt;

import java.time.LocalDate;

@ApplicationScoped
@IfBuildProfile("dev")
public class DataSeeder {

    @ConfigProperty(name = "plantmanager.seeder.enabled", defaultValue = "true")
    boolean seederEnabled;

    @ConfigProperty(name = "plantmanager.seeder.password", defaultValue = "password123")
    String seederPassword;

    @Transactional
    void onStart(@Observes StartupEvent ev) {
        if (!seederEnabled) {
            Log.info("🌱 DataSeeder is disabled by configuration.");
            return;
        }

        Log.info("🌱 Checking if test data needs to be seeded...");

        if (UserEntity.findByEmail("test@test.com").isPresent()) {
            Log.info("✅ Test data already exists. Skipping.");
            return;
        }

        Log.info("🚀 Seeding test data (Direct Entity Mode)...");

        try {
            // 1. Create User
            UserEntity user = new UserEntity();
            user.email = "test@test.com";
            user.passwordHash = BCrypt.hashpw(seederPassword, BCrypt.gensalt(12));
            user.displayName = "Test User";
            user.role = UserEntity.UserRole.MEMBER;
            user.persist();

            // 2. Create House 1
            HouseEntity house = new HouseEntity();
            house.name = "Appartement Test";

            house.persist(); // MUST persist before linking

            // 3. Link User to House (Active Membership)
            UserHouseEntity membership = new UserHouseEntity();
            membership.user = user;
            membership.house = house;
            membership.role = UserEntity.UserRole.OWNER;
            membership.isActive = true;
            membership.persist();

            // 4. Create Rooms
            RoomEntity salon = createRoom(house, "Salon", RoomType.LIVING_ROOM);
            RoomEntity chambre = createRoom(house, "Chambre", RoomType.BEDROOM);
            RoomEntity balcon = createRoom(house, "Balcon", RoomType.BALCONY);

            // 5. Create Plants
            createPlant(user, house, salon, "Monstera", 7, Exposure.PARTIAL_SHADE, false, false, false, false);

            // Thirsty Pothos
            createPlant(user, house, salon, "Pothos", 7, Exposure.SHADE, false, false, false, true);

            createPlant(user, house, chambre, "Calathea", 10, Exposure.SHADE, true, false, false, false);
            createPlant(user, house, balcon, "Fugère", 5, Exposure.SHADE, false, true, false, false);
            createPlant(user, house, salon, "Ficus", 14, Exposure.SUN, false, false, true, false);

            createPlant(user, house, chambre, "Orchidée", 7, Exposure.SUN, true, true, false, false);
            createPlant(user, house, balcon, "Bambou", 3, Exposure.SUN, true, false, true, false);
            createPlant(user, house, salon, "Yucca", 20, Exposure.SUN, false, true, true, false);

            // All Issues + Thirsty
            createPlant(user, house, chambre, "Bégonia", 5, Exposure.PARTIAL_SHADE, true, true, true, true);

            // 6. Secondary House (Inactive)
            HouseEntity house2 = new HouseEntity();
            house2.name = "Maison de Vacances";

            house2.persist();

            UserHouseEntity membership2 = new UserHouseEntity();
            membership2.user = user;
            membership2.house = house2;
            membership2.role = UserEntity.UserRole.OWNER;
            membership2.isActive = false; // Not active by default
            membership2.persist();

            RoomEntity jardin = createRoom(house2, "Jardin", RoomType.GARDEN);
            RoomEntity cuisine = createRoom(house2, "Cuisine", RoomType.KITCHEN);

            // Note: Plants usually require user to have active house logic in Service, but
            // Entity doesn't care.
            // However, UserPlantEntity usually stores 'user' and 'room'.
            // It might traverse room->house to check consistency, but core mapping is
            // enough.
            createPlant(user, house2, cuisine, "Basilic", 3, Exposure.SUN, false, false, false, true);
            createPlant(user, house2, jardin, "Rosier", 5, Exposure.SUN, false, false, true, false);

            Log.info("✅ Test data seeded successfully!");

        } catch (Exception e) {
            Log.error("❌ Failed to seed test data", e);
        }
    }

    private RoomEntity createRoom(HouseEntity house, String name, RoomType type) {
        RoomEntity room = new RoomEntity();
        room.house = house;
        room.name = name;
        room.type = type;
        room.persist();
        return room;
    }

    private void createPlant(UserEntity user, HouseEntity house, RoomEntity room, String nickname, int interval,
            Exposure exposure,
            boolean isSick, boolean isWilted, boolean needsRepotting, boolean forceThirsty) {

        UserPlantEntity plant = new UserPlantEntity();
        plant.user = user;
        plant.room = room; // Link to room directly
        plant.nickname = nickname;
        plant.wateringIntervalDays = interval;
        plant.exposure = exposure;
        plant.notes = "Created by DataSeeder";

        plant.isSick = isSick;
        plant.isWilted = isWilted;
        plant.needsRepotting = needsRepotting;

        // Default dates
        // lastWatered defaults to created_at/now usually if not set.
        // We set it explicitly if thirsty.
        if (forceThirsty) {
            plant.lastWatered = LocalDate.now().minusDays(30).atStartOfDay().atOffset(java.time.ZoneOffset.UTC);
        } else {
            plant.lastWatered = java.time.OffsetDateTime.now();
        }

        plant.createdAt = java.time.OffsetDateTime.now();

        plant.persist();
    }
}
