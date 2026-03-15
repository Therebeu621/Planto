package com.plantmanager.service;

import com.plantmanager.dto.CareRecommendationDTO;
import com.plantmanager.dto.McpSchemaResponse;
import com.plantmanager.dto.McpSchemaResponse.ParameterSchema;
import com.plantmanager.dto.McpSchemaResponse.ToolSchema;
import com.plantmanager.dto.McpToolRequest;
import com.plantmanager.dto.McpToolResponse;
import com.plantmanager.dto.weather.PlantCareSheetDTO;
import com.plantmanager.dto.weather.WeatherWateringAdviceDTO;
import com.plantmanager.entity.*;
import com.plantmanager.entity.enums.CareAction;
import com.plantmanager.entity.enums.Exposure;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.jboss.logging.Logger;

import java.time.OffsetDateTime;
import java.util.*;

/**
 * Service handling MCP (Model Context Protocol) tool execution.
 * Acts as a bridge between LLM tools (Goose/Mistral) and the plant management business logic.
 * Each tool maps natural language commands to concrete API operations.
 */
@ApplicationScoped
public class McpService {

    private static final Logger LOG = Logger.getLogger(McpService.class);

    @Inject
    PlantDatabaseService plantDatabase;

    @Inject
    PerenualService perenualService;

    @Inject
    WeatherService weatherService;

    /**
     * Execute an MCP tool by name with the given parameters.
     *
     * @param request the tool request containing tool name and parameters
     * @param userId  the authenticated user ID (from MCP API key resolution or JWT)
     * @return tool response with status, message, and data
     */
    @Transactional
    public McpToolResponse executeTool(McpToolRequest request, UUID userId) {
        if (request.tool() == null || request.tool().isBlank()) {
            return McpToolResponse.error("Tool name is required");
        }

        LOG.infof("MCP tool execution: tool=%s, userId=%s, params=%s",
                request.tool(), userId, request.params());

        return switch (request.tool()) {
            case "list_plants" -> listPlants(userId);
            case "search_plants" -> searchPlants(request);
            case "add_plant" -> addPlant(userId, request);
            case "water_plant" -> waterPlant(userId, request);
            case "water_all_plants" -> waterAllPlants(userId);
            case "list_rooms" -> listRooms(userId);
            case "create_room" -> createRoom(userId, request);
            case "move_plant" -> movePlant(userId, request);
            case "delete_plant" -> deletePlant(userId, request);
            case "get_plant_detail" -> getPlantDetail(userId, request);
            case "list_plants_needing_water" -> listPlantsNeedingWater(userId);
            case "get_care_recommendation" -> getCareRecommendation(request);
            case "update_plant" -> updatePlant(userId, request);
            case "delete_room" -> deleteRoom(userId, request);
            case "get_weather_watering_advice" -> getWeatherWateringAdvice(request);
            case "enrich_plant_caresheet" -> enrichPlantCareSheet(request);
            default -> McpToolResponse.error("Unknown tool: " + request.tool()
                    + ". Available tools: list_plants, search_plants, add_plant, water_plant, water_all_plants, list_rooms, create_room, move_plant, delete_plant, get_plant_detail, list_plants_needing_water, get_care_recommendation, update_plant, delete_room, get_weather_watering_advice, enrich_plant_caresheet");
        };
    }

    /**
     * List all plants for the user.
     */
    private McpToolResponse listPlants(UUID userId) {
        List<UserPlantEntity> plants = UserPlantEntity.findByUser(userId);

        if (plants.isEmpty()) {
            return McpToolResponse.success("Vous n'avez aucune plante pour le moment.", List.of());
        }

        List<Map<String, Object>> result = plants.stream().map(this::plantToMap).toList();
        return McpToolResponse.success(
                String.format("Vous avez %d plante(s).", plants.size()),
                result
        );
    }

    /**
     * Search plants by name in the species database.
     */
    private McpToolResponse searchPlants(McpToolRequest request) {
        String query = request.param("query");
        if (query == null || query.length() < 2) {
            return McpToolResponse.error("Parameter 'query' is required (min 2 characters)");
        }

        List<PlantDatabaseService.PlantData> results = plantDatabase.search(query);

        if (results.isEmpty()) {
            return McpToolResponse.success(
                    String.format("Aucune espece trouvee pour '%s'.", query),
                    List.of()
            );
        }

        List<Map<String, Object>> data = results.stream().map(p -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("nomFrancais", p.nomFrancais);
            m.put("nomLatin", p.nomLatin);
            m.put("arrosageFrequenceJours", p.arrosageFrequenceJours);
            m.put("luminosite", p.luminosite);
            return m;
        }).toList();

        return McpToolResponse.success(
                String.format("%d espece(s) trouvee(s) pour '%s'.", results.size(), query),
                data
        );
    }

    /**
     * Add a new plant for the user.
     * Resolves species from name, room from name, and creates the plant.
     */
    private McpToolResponse addPlant(UUID userId, McpToolRequest request) {
        String nickname = request.param("nickname");
        String speciesName = request.param("speciesName");
        String roomName = request.param("roomName");

        if (nickname == null || nickname.isBlank()) {
            nickname = speciesName != null ? speciesName : "Ma plante";
        }
        // Truncate nickname to avoid DB column overflow
        if (nickname.length() > 100) {
            nickname = nickname.substring(0, 100);
        }

        UserEntity user = UserEntity.findById(userId);
        if (user == null) {
            return McpToolResponse.error("User not found");
        }

        UserPlantEntity plant = new UserPlantEntity();
        plant.user = user;
        plant.nickname = nickname;
        plant.wateringIntervalDays = 7;
        plant.exposure = Exposure.PARTIAL_SHADE;

        // Resolve species from name if provided
        if (speciesName != null && !speciesName.isBlank()) {
            PlantDatabaseService.PlantData speciesData = plantDatabase.getByName(speciesName);
            if (speciesData != null) {
                plant.customSpecies = speciesData.nomLatin;
                plant.wateringIntervalDays = speciesData.arrosageFrequenceJours;
                // Map luminosite to Exposure
                plant.exposure = mapLuminositeToExposure(speciesData.luminosite);
            } else {
                plant.customSpecies = speciesName;
            }
        }

        // Resolve room from name if provided
        if (roomName != null && !roomName.isBlank()) {
            UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
            if (membership != null) {
                List<RoomEntity> rooms = RoomEntity.findByHouse(membership.house.id);
                RoomEntity matchingRoom = rooms.stream()
                        .filter(r -> r.name.equalsIgnoreCase(roomName))
                        .findFirst()
                        .orElse(null);
                if (matchingRoom != null) {
                    plant.room = matchingRoom;
                }
            }
        }

        plant.persist();

        Map<String, Object> data = plantToMap(plant);
        return McpToolResponse.success(
                String.format("Plante '%s' ajoutee avec succes!", plant.nickname),
                data
        );
    }

    /**
     * Water a plant by name.
     */
    private McpToolResponse waterPlant(UUID userId, McpToolRequest request) {
        String plantName = request.param("plantName");
        if (plantName == null || plantName.isBlank()) {
            return McpToolResponse.error("Parameter 'plantName' is required");
        }

        // Search in user's plants by nickname
        List<UserPlantEntity> plants = UserPlantEntity.searchByNickname(userId, plantName);
        if (plants.isEmpty()) {
            return McpToolResponse.error(
                    String.format("Aucune plante trouvee avec le nom '%s'.", plantName));
        }

        // Water the first matching plant
        UserPlantEntity plant = plants.get(0);
        plant.water();

        // Create care log
        UserEntity user = UserEntity.findById(userId);
        CareLogEntity careLog = new CareLogEntity();
        careLog.plant = plant;
        careLog.user = user;
        careLog.action = CareAction.WATERING;
        careLog.performedAt = OffsetDateTime.now();
        careLog.persist();

        Map<String, Object> data = plantToMap(plant);
        return McpToolResponse.success(
                String.format("Plante '%s' arrosee avec succes!", plant.nickname),
                data
        );
    }

    /**
     * Water ALL plants for the user ("J'ai arrosé toutes mes plantes").
     */
    private McpToolResponse waterAllPlants(UUID userId) {
        List<UserPlantEntity> plants = UserPlantEntity.findByUser(userId);

        if (plants.isEmpty()) {
            return McpToolResponse.success("Vous n'avez aucune plante a arroser.", List.of());
        }

        UserEntity user = UserEntity.findById(userId);
        int count = 0;
        for (UserPlantEntity plant : plants) {
            plant.water();

            CareLogEntity careLog = new CareLogEntity();
            careLog.plant = plant;
            careLog.user = user;
            careLog.action = CareAction.WATERING;
            careLog.performedAt = OffsetDateTime.now();
            careLog.persist();
            count++;
        }

        List<Map<String, Object>> result = plants.stream().map(this::plantToMap).toList();
        return McpToolResponse.success(
                String.format("%d plante(s) arrosee(s) avec succes!", count),
                result
        );
    }

    /**
     * List all rooms in the user's active house.
     */
    private McpToolResponse listRooms(UUID userId) {
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership == null) {
            return McpToolResponse.error("Vous n'appartenez a aucune maison.");
        }

        List<RoomEntity> rooms = RoomEntity.findByHouse(membership.house.id);
        if (rooms.isEmpty()) {
            return McpToolResponse.success("Aucune piece dans votre maison.", List.of());
        }

        List<Map<String, Object>> data = rooms.stream().map(r -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", r.id.toString());
            m.put("name", r.name);
            m.put("type", r.type != null ? r.type.name() : null);
            m.put("plantCount", UserPlantEntity.countByRoom(r.id));
            return m;
        }).toList();

        return McpToolResponse.success(
                String.format("%d piece(s) dans votre maison.", rooms.size()),
                data
        );
    }

    /**
     * Create a new room in the user's active house.
     */
    private McpToolResponse createRoom(UUID userId, McpToolRequest request) {
        String rawName = request.param("name");
        if (rawName == null || rawName.isBlank()) {
            return McpToolResponse.error("Parameter 'name' is required.");
        }
        final String name = rawName.length() > 100 ? rawName.substring(0, 100) : rawName;

        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership == null) {
            return McpToolResponse.error("Vous n'appartenez a aucune maison.");
        }

        // Check for duplicate room name
        List<RoomEntity> existing = RoomEntity.findByHouse(membership.house.id);
        boolean duplicate = existing.stream().anyMatch(r -> r.name.equalsIgnoreCase(name));
        if (duplicate) {
            return McpToolResponse.error(
                    String.format("Une piece nommee '%s' existe deja.", name));
        }

        RoomEntity room = new RoomEntity();
        room.house = membership.house;
        room.name = name;
        room.persist();

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("id", room.id.toString());
        data.put("name", room.name);
        data.put("type", room.type != null ? room.type.name() : null);

        return McpToolResponse.success(
                String.format("Piece '%s' creee avec succes!", room.name),
                data
        );
    }

    /**
     * Move a plant to a different room.
     */
    private McpToolResponse movePlant(UUID userId, McpToolRequest request) {
        String plantName = request.param("plantName");
        String roomName = request.param("roomName");

        if (plantName == null || plantName.isBlank()) {
            return McpToolResponse.error("Parameter 'plantName' is required.");
        }
        if (roomName == null || roomName.isBlank()) {
            return McpToolResponse.error("Parameter 'roomName' is required.");
        }

        // Find the plant
        List<UserPlantEntity> plants = UserPlantEntity.searchByNickname(userId, plantName);
        if (plants.isEmpty()) {
            return McpToolResponse.error(
                    String.format("Aucune plante trouvee avec le nom '%s'.", plantName));
        }

        // Find the room
        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership == null) {
            return McpToolResponse.error("Vous n'appartenez a aucune maison.");
        }

        List<RoomEntity> rooms = RoomEntity.findByHouse(membership.house.id);
        RoomEntity targetRoom = rooms.stream()
                .filter(r -> r.name.equalsIgnoreCase(roomName))
                .findFirst()
                .orElse(null);

        if (targetRoom == null) {
            return McpToolResponse.error(
                    String.format("Aucune piece trouvee avec le nom '%s'.", roomName));
        }

        UserPlantEntity plant = plants.get(0);
        plant.room = targetRoom;
        plant.persist();

        Map<String, Object> data = plantToMap(plant);
        return McpToolResponse.success(
                String.format("Plante '%s' deplacee dans '%s' avec succes!", plant.nickname, targetRoom.name),
                data
        );
    }

    /**
     * Delete a plant by name ("Ma plante est morte, supprime-la").
     */
    private McpToolResponse deletePlant(UUID userId, McpToolRequest request) {
        String plantName = request.param("plantName");
        if (plantName == null || plantName.isBlank()) {
            return McpToolResponse.error("Parameter 'plantName' is required.");
        }

        List<UserPlantEntity> plants = UserPlantEntity.searchByNickname(userId, plantName);
        if (plants.isEmpty()) {
            return McpToolResponse.error(
                    String.format("Aucune plante trouvee avec le nom '%s'.", plantName));
        }

        UserPlantEntity plant = plants.get(0);
        String deletedName = plant.nickname;
        UUID plantId = plant.id;

        // Delete care logs first (foreign key constraint)
        CareLogEntity.delete("plant.id", plantId);
        // Delete notifications linked to the plant
        NotificationEntity.delete("plant.id", plantId);
        plant.delete();

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("deletedPlantId", plantId.toString());
        data.put("deletedPlantName", deletedName);

        return McpToolResponse.success(
                String.format("Plante '%s' supprimee avec succes.", deletedName),
                data
        );
    }

    /**
     * Get detailed info about a plant by name.
     */
    private McpToolResponse getPlantDetail(UUID userId, McpToolRequest request) {
        String plantName = request.param("plantName");
        if (plantName == null || plantName.isBlank()) {
            return McpToolResponse.error("Parameter 'plantName' is required.");
        }

        List<UserPlantEntity> plants = UserPlantEntity.searchByNickname(userId, plantName);
        if (plants.isEmpty()) {
            return McpToolResponse.error(
                    String.format("Aucune plante trouvee avec le nom '%s'.", plantName));
        }

        UserPlantEntity plant = plants.get(0);
        Map<String, Object> data = plantToMap(plant);
        // Add extra detail fields
        data.put("notes", plant.notes);
        data.put("needsRepotting", plant.needsRepotting);
        data.put("exposure", plant.exposure != null ? plant.exposure.name() : null);
        data.put("acquiredAt", plant.acquiredAt != null ? plant.acquiredAt.toString() : null);
        data.put("createdAt", plant.createdAt != null ? plant.createdAt.toString() : null);

        // Add recent care history
        List<CareLogEntity> logs = CareLogEntity.findByPlantLimited(plant.id, 5);
        List<Map<String, String>> careHistory = logs.stream().map(log -> {
            Map<String, String> entry = new LinkedHashMap<>();
            entry.put("action", log.action.name());
            entry.put("date", log.performedAt != null ? log.performedAt.toString() : null);
            entry.put("user", log.user != null ? log.user.displayName : null);
            return entry;
        }).toList();
        data.put("recentCareHistory", careHistory);

        return McpToolResponse.success(
                String.format("Details de la plante '%s'.", plant.nickname),
                data
        );
    }

    /**
     * List plants that need watering ("Quelles plantes ont besoin d'eau ?").
     */
    private McpToolResponse listPlantsNeedingWater(UUID userId) {
        List<UserPlantEntity> thirsty = UserPlantEntity.findNeedingWater(userId);

        if (thirsty.isEmpty()) {
            return McpToolResponse.success(
                    "Toutes vos plantes sont bien arrosees! Aucune n'a besoin d'eau.",
                    List.of()
            );
        }

        List<Map<String, Object>> result = thirsty.stream().map(this::plantToMap).toList();
        return McpToolResponse.success(
                String.format("%d plante(s) ont besoin d'eau.", thirsty.size()),
                result
        );
    }

    /**
     * Get care recommendation for a species ("Comment entretenir un ficus ?").
     */
    private McpToolResponse getCareRecommendation(McpToolRequest request) {
        String speciesName = request.param("speciesName");
        if (speciesName == null || speciesName.isBlank()) {
            return McpToolResponse.error("Parameter 'speciesName' is required.");
        }

        CareRecommendationDTO care = perenualService.getCareByName(speciesName);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("speciesName", speciesName);
        data.put("wateringFrequency", care.wateringFrequency());
        data.put("recommendedIntervalDays", care.recommendedIntervalDays());
        data.put("sunlight", care.sunlight());
        data.put("careLevel", care.careLevel());
        data.put("description", care.description());
        data.put("recommendation", care.getRecommendationMessage());

        // Also try to find in local plant database for extra info
        PlantDatabaseService.PlantData localData = plantDatabase.getByName(speciesName);
        if (localData != null) {
            data.put("nomLatin", localData.nomLatin);
            data.put("luminosite", localData.luminosite);
        }

        return McpToolResponse.success(
                String.format("Conseils d'entretien pour '%s': %s", speciesName, care.getRecommendationMessage()),
                data
        );
    }

    /**
     * Update a plant's properties (rename, mark sick/wilted, change notes, watering interval).
     */
    private McpToolResponse updatePlant(UUID userId, McpToolRequest request) {
        String plantName = request.param("plantName");
        if (plantName == null || plantName.isBlank()) {
            return McpToolResponse.error("Parameter 'plantName' is required.");
        }

        List<UserPlantEntity> plants = UserPlantEntity.searchByNickname(userId, plantName);
        if (plants.isEmpty()) {
            return McpToolResponse.error(
                    String.format("Aucune plante trouvee avec le nom '%s'.", plantName));
        }

        UserPlantEntity plant = plants.get(0);
        List<String> changes = new ArrayList<>();

        // Update nickname
        String newNickname = request.param("newNickname");
        if (newNickname != null && !newNickname.isBlank()) {
            String truncated = newNickname.length() > 100 ? newNickname.substring(0, 100) : newNickname;
            plant.nickname = truncated;
            changes.add("nom -> " + truncated);
        }

        // Update notes
        String notes = request.param("notes");
        if (notes != null) {
            plant.notes = notes.length() > 500 ? notes.substring(0, 500) : notes;
            changes.add("notes mises a jour");
        }

        // Update isSick
        String isSick = request.param("isSick");
        if (isSick != null) {
            plant.isSick = "true".equalsIgnoreCase(isSick);
            changes.add(plant.isSick ? "marquee malade" : "marquee non malade");
        }

        // Update isWilted
        String isWilted = request.param("isWilted");
        if (isWilted != null) {
            plant.isWilted = "true".equalsIgnoreCase(isWilted);
            changes.add(plant.isWilted ? "marquee fanee" : "marquee non fanee");
        }

        // Update needsRepotting
        String needsRepotting = request.param("needsRepotting");
        if (needsRepotting != null) {
            plant.needsRepotting = "true".equalsIgnoreCase(needsRepotting);
            changes.add(plant.needsRepotting ? "rempotage necessaire" : "rempotage non necessaire");
        }

        // Update watering interval
        String intervalStr = request.param("wateringIntervalDays");
        if (intervalStr != null) {
            try {
                int interval = Integer.parseInt(intervalStr);
                if (interval >= 1 && interval <= 365) {
                    plant.wateringIntervalDays = interval;
                    changes.add("intervalle arrosage -> " + interval + " jours");
                }
            } catch (NumberFormatException ignored) {
                // Skip invalid number
            }
        }

        if (changes.isEmpty()) {
            return McpToolResponse.error(
                    "Aucun parametre de mise a jour fourni. Parametres disponibles: newNickname, notes, isSick, isWilted, needsRepotting, wateringIntervalDays");
        }

        plant.persist();

        Map<String, Object> data = plantToMap(plant);
        return McpToolResponse.success(
                String.format("Plante '%s' mise a jour: %s.", plant.nickname, String.join(", ", changes)),
                data
        );
    }

    /**
     * Delete a room by name.
     */
    private McpToolResponse deleteRoom(UUID userId, McpToolRequest request) {
        String roomName = request.param("roomName");
        if (roomName == null || roomName.isBlank()) {
            return McpToolResponse.error("Parameter 'roomName' is required.");
        }

        UserHouseEntity membership = UserHouseEntity.findActiveByUser(userId);
        if (membership == null) {
            return McpToolResponse.error("Vous n'appartenez a aucune maison.");
        }

        List<RoomEntity> rooms = RoomEntity.findByHouse(membership.house.id);
        RoomEntity room = rooms.stream()
                .filter(r -> r.name.equalsIgnoreCase(roomName))
                .findFirst()
                .orElse(null);

        if (room == null) {
            return McpToolResponse.error(
                    String.format("Aucune piece trouvee avec le nom '%s'.", roomName));
        }

        // Orphan plants in this room (set room to null instead of deleting them)
        List<UserPlantEntity> plantsInRoom = UserPlantEntity.findByRoom(room.id);
        int orphanedCount = plantsInRoom.size();
        for (UserPlantEntity plant : plantsInRoom) {
            plant.room = null;
            plant.persist();
        }

        String deletedName = room.name;
        room.delete();

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("deletedRoomName", deletedName);
        data.put("orphanedPlants", orphanedCount);

        String msg = orphanedCount > 0
                ? String.format("Piece '%s' supprimee. %d plante(s) n'ont plus de piece assignee.", deletedName, orphanedCount)
                : String.format("Piece '%s' supprimee avec succes.", deletedName);

        return McpToolResponse.success(msg, data);
    }

    /**
     * Get weather-based watering advice ("Quel temps fait-il ? Dois-je arroser ?").
     */
    private McpToolResponse getWeatherWateringAdvice(McpToolRequest request) {
        String city = request.param("city");

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice(city);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("city", advice.city());
        data.put("temperature", advice.temperature());
        data.put("humidity", advice.humidity());
        data.put("weatherDescription", advice.weatherDescription());
        data.put("rainMm", advice.rainMm());
        data.put("shouldSkipOutdoorWatering", advice.shouldSkipOutdoorWatering());
        data.put("indoorAdvice", advice.indoorAdvice());
        data.put("intervalAdjustmentFactor", advice.intervalAdjustmentFactor());
        data.put("advices", advice.advices());

        String summary = String.join(" ", advice.advices());
        return McpToolResponse.success(
                String.format("Météo %s: %s. %s", advice.city(), advice.weatherDescription(), summary),
                data
        );
    }

    /**
     * Generate enriched care sheet for a plant ("Donne-moi la fiche de soin complète du monstera").
     */
    private McpToolResponse enrichPlantCareSheet(McpToolRequest request) {
        String speciesName = request.param("speciesName");
        if (speciesName == null || speciesName.isBlank()) {
            return McpToolResponse.error("Parameter 'speciesName' is required.");
        }

        String city = request.param("city");

        PlantCareSheetDTO sheet = weatherService.generateCareSheet(speciesName, city);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("speciesName", sheet.speciesName());
        data.put("category", sheet.category());
        data.put("wateringFrequency", sheet.wateringFrequency());
        data.put("wateringIntervalDays", sheet.wateringIntervalDays());
        data.put("sunlight", sheet.sunlight());
        data.put("careLevel", sheet.careLevel());
        data.put("wateringTip", sheet.wateringTip());
        data.put("seasonalAdvice", sheet.seasonalAdvice());
        data.put("commonProblems", sheet.commonProblems());
        data.put("weatherAdvice", sheet.weatherAdvice());
        data.put("careSummary", sheet.careSummary());

        return McpToolResponse.success(sheet.careSummary(), data);
    }

    /**
     * Build the MCP schema describing all available tools.
     */
    public McpSchemaResponse getSchema() {
        List<ToolSchema> tools = List.of(
                new ToolSchema(
                        "list_plants",
                        "Lister toutes les plantes de l'utilisateur",
                        Map.of()
                ),
                new ToolSchema(
                        "search_plants",
                        "Rechercher des especes de plantes dans la base de donnees",
                        Map.of("query", new ParameterSchema("string", true,
                                "Terme de recherche (nom francais ou latin, min 2 caracteres)"))
                ),
                new ToolSchema(
                        "add_plant",
                        "Ajouter une nouvelle plante au jardin de l'utilisateur",
                        Map.of(
                                "speciesName", new ParameterSchema("string", false,
                                        "Nom de l'espece (francais ou latin)"),
                                "roomName", new ParameterSchema("string", false,
                                        "Nom de la piece ou placer la plante"),
                                "nickname", new ParameterSchema("string", false,
                                        "Surnom de la plante")
                        )
                ),
                new ToolSchema(
                        "water_plant",
                        "Arroser une plante par son nom",
                        Map.of("plantName", new ParameterSchema("string", true,
                                "Nom ou surnom de la plante a arroser"))
                ),
                new ToolSchema(
                        "water_all_plants",
                        "Arroser toutes les plantes de l'utilisateur",
                        Map.of()
                ),
                new ToolSchema(
                        "list_rooms",
                        "Lister toutes les pieces de la maison de l'utilisateur",
                        Map.of()
                ),
                new ToolSchema(
                        "create_room",
                        "Creer une nouvelle piece dans la maison",
                        Map.of("name", new ParameterSchema("string", true,
                                "Nom de la piece a creer"))
                ),
                new ToolSchema(
                        "move_plant",
                        "Deplacer une plante dans une autre piece",
                        Map.of(
                                "plantName", new ParameterSchema("string", true,
                                        "Nom ou surnom de la plante a deplacer"),
                                "roomName", new ParameterSchema("string", true,
                                        "Nom de la piece de destination")
                        )
                ),
                new ToolSchema(
                        "delete_plant",
                        "Supprimer une plante par son nom",
                        Map.of("plantName", new ParameterSchema("string", true,
                                "Nom ou surnom de la plante a supprimer"))
                ),
                new ToolSchema(
                        "get_plant_detail",
                        "Obtenir les details complets d'une plante (historique de soins, etat, etc.)",
                        Map.of("plantName", new ParameterSchema("string", true,
                                "Nom ou surnom de la plante"))
                ),
                new ToolSchema(
                        "list_plants_needing_water",
                        "Lister les plantes qui ont besoin d'etre arrosees",
                        Map.of()
                ),
                new ToolSchema(
                        "get_care_recommendation",
                        "Obtenir des conseils d'entretien pour une espece de plante",
                        Map.of("speciesName", new ParameterSchema("string", true,
                                "Nom de l'espece (francais ou latin)"))
                ),
                new ToolSchema(
                        "update_plant",
                        "Modifier les proprietes d'une plante (nom, etat de sante, notes, intervalle d'arrosage)",
                        Map.of(
                                "plantName", new ParameterSchema("string", true,
                                        "Nom actuel de la plante a modifier"),
                                "newNickname", new ParameterSchema("string", false,
                                        "Nouveau surnom de la plante"),
                                "notes", new ParameterSchema("string", false,
                                        "Notes sur la plante"),
                                "isSick", new ParameterSchema("string", false,
                                        "true/false - la plante est malade"),
                                "isWilted", new ParameterSchema("string", false,
                                        "true/false - la plante est fanee"),
                                "needsRepotting", new ParameterSchema("string", false,
                                        "true/false - la plante a besoin d'etre rempotee"),
                                "wateringIntervalDays", new ParameterSchema("string", false,
                                        "Intervalle d'arrosage en jours (1-365)")
                        )
                ),
                new ToolSchema(
                        "delete_room",
                        "Supprimer une piece de la maison (les plantes sont conservees sans piece)",
                        Map.of("roomName", new ParameterSchema("string", true,
                                "Nom de la piece a supprimer"))
                ),
                new ToolSchema(
                        "get_weather_watering_advice",
                        "Obtenir des conseils d'arrosage bases sur la meteo actuelle (pluie, temperature, humidite)",
                        Map.of("city", new ParameterSchema("string", false,
                                "Ville pour la meteo (defaut: Paris)"))
                ),
                new ToolSchema(
                        "enrich_plant_caresheet",
                        "Generer une fiche de soin complete et enrichie pour une espece (conseils saisonniers, problemes courants, meteo)",
                        Map.of(
                                "speciesName", new ParameterSchema("string", true,
                                        "Nom de l'espece (francais ou latin)"),
                                "city", new ParameterSchema("string", false,
                                        "Ville pour les conseils meteo (defaut: Paris)")
                        )
                )
        );

        return new McpSchemaResponse("Plant Management MCP", "1.0.0", tools);
    }

    /**
     * Convert a plant entity to a simple map for MCP responses.
     */
    private Map<String, Object> plantToMap(UserPlantEntity plant) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", plant.id.toString());
        m.put("nickname", plant.nickname);
        m.put("species", plant.customSpecies != null ? plant.customSpecies
                : (plant.species != null ? plant.species.commonName : null));
        m.put("room", plant.room != null ? plant.room.name : null);
        m.put("wateringIntervalDays", plant.wateringIntervalDays);
        m.put("lastWatered", plant.lastWatered != null ? plant.lastWatered.toString() : null);
        m.put("nextWateringDate", plant.nextWateringDate != null ? plant.nextWateringDate.toString() : null);
        m.put("needsWatering", plant.needsWatering());
        m.put("isSick", plant.isSick);
        m.put("isWilted", plant.isWilted);
        return m;
    }

    /**
     * Map luminosite string from plant database to Exposure enum.
     */
    private Exposure mapLuminositeToExposure(String luminosite) {
        if (luminosite == null) return Exposure.PARTIAL_SHADE;
        String lower = luminosite.toLowerCase();
        if (lower.contains("direct") || lower.contains("plein soleil") || lower.contains("vive")) {
            return Exposure.SUN;
        } else if (lower.contains("ombre") || lower.contains("faible") || lower.contains("tamise")) {
            return Exposure.SHADE;
        }
        return Exposure.PARTIAL_SHADE;
    }
}
