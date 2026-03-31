package com.plantmanager.dto;

import com.plantmanager.dto.perenual.PerenualDetailsResponse;
import com.plantmanager.dto.perenual.PerenualSearchResponse;
import com.plantmanager.dto.trefle.TrefleDetailResponse;
import com.plantmanager.dto.trefle.TrefleSearchResponse;
import com.plantmanager.dto.weather.OpenWeatherResponse;
import com.plantmanager.entity.enums.Exposure;
import com.plantmanager.entity.enums.RoomType;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
class DtoCoverageTest {

    // ========================================================================
    // 1. OpenWeatherResponse
    // ========================================================================

    @Test
    void openWeatherResponse_gettersSetters() {
        OpenWeatherResponse resp = new OpenWeatherResponse();

        OpenWeatherResponse.Weather w = new OpenWeatherResponse.Weather();
        w.setId(800);
        w.setMain("Clear");
        w.setDescription("clear sky");
        w.setIcon("01d");
        assertEquals(800, w.getId());
        assertEquals("Clear", w.getMain());
        assertEquals("clear sky", w.getDescription());
        assertEquals("01d", w.getIcon());

        resp.setWeather(List.of(w));
        assertEquals(1, resp.getWeather().size());

        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setTemp(25.5);
        main.setFeelsLike(26.0);
        main.setTempMin(20.0);
        main.setTempMax(30.0);
        main.setHumidity(65);
        assertEquals(25.5, main.getTemp());
        assertEquals(26.0, main.getFeelsLike());
        assertEquals(20.0, main.getTempMin());
        assertEquals(30.0, main.getTempMax());
        assertEquals(65, main.getHumidity());
        resp.setMain(main);
        assertSame(main, resp.getMain());

        OpenWeatherResponse.Wind wind = new OpenWeatherResponse.Wind();
        wind.setSpeed(5.5);
        assertEquals(5.5, wind.getSpeed());
        resp.setWind(wind);
        assertSame(wind, resp.getWind());

        OpenWeatherResponse.Rain rain = new OpenWeatherResponse.Rain();
        rain.setOneHour(1.5);
        rain.setThreeHours(3.0);
        assertEquals(1.5, rain.getOneHour());
        assertEquals(3.0, rain.getThreeHours());
        resp.setRain(rain);
        assertSame(rain, resp.getRain());

        OpenWeatherResponse.Clouds clouds = new OpenWeatherResponse.Clouds();
        clouds.setAll(75);
        assertEquals(75, clouds.getAll());
        resp.setClouds(clouds);
        assertSame(clouds, resp.getClouds());

        resp.setName("Paris");
        assertEquals("Paris", resp.getName());
    }

    @Test
    void openWeatherResponse_isRaining_withRain() {
        OpenWeatherResponse resp = buildWeatherResponse("Rain");
        assertTrue(resp.isRaining());
    }

    @Test
    void openWeatherResponse_isRaining_withDrizzle() {
        OpenWeatherResponse resp = buildWeatherResponse("Drizzle");
        assertTrue(resp.isRaining());
    }

    @Test
    void openWeatherResponse_isRaining_withThunderstorm() {
        OpenWeatherResponse resp = buildWeatherResponse("Thunderstorm");
        assertTrue(resp.isRaining());
    }

    @Test
    void openWeatherResponse_isRaining_withClear() {
        OpenWeatherResponse resp = buildWeatherResponse("Clear");
        assertFalse(resp.isRaining());
    }

    @Test
    void openWeatherResponse_isRaining_nullWeather() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        assertFalse(resp.isRaining());
    }

    @Test
    void openWeatherResponse_isRaining_emptyWeather() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        resp.setWeather(new ArrayList<>());
        assertFalse(resp.isRaining());
    }

    @Test
    void openWeatherResponse_getRainMm_withOneHour() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Rain rain = new OpenWeatherResponse.Rain();
        rain.setOneHour(2.5);
        rain.setThreeHours(5.0);
        resp.setRain(rain);
        assertEquals(2.5, resp.getRainMm());
    }

    @Test
    void openWeatherResponse_getRainMm_withThreeHoursOnly() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Rain rain = new OpenWeatherResponse.Rain();
        rain.setThreeHours(4.0);
        resp.setRain(rain);
        assertEquals(4.0, resp.getRainMm());
    }

    @Test
    void openWeatherResponse_getRainMm_nullRain() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        assertEquals(0, resp.getRainMm());
    }

    @Test
    void openWeatherResponse_getRainMm_rainWithNoValues() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        resp.setRain(new OpenWeatherResponse.Rain());
        assertEquals(0, resp.getRainMm());
    }

    @Test
    void openWeatherResponse_isHighHumidity_above80() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setHumidity(85);
        resp.setMain(main);
        assertTrue(resp.isHighHumidity());
    }

    @Test
    void openWeatherResponse_isHighHumidity_at80() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setHumidity(80);
        resp.setMain(main);
        assertFalse(resp.isHighHumidity());
    }

    @Test
    void openWeatherResponse_isHighHumidity_below80() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setHumidity(50);
        resp.setMain(main);
        assertFalse(resp.isHighHumidity());
    }

    @Test
    void openWeatherResponse_isVeryHot_above30() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setTemp(35.0);
        resp.setMain(main);
        assertTrue(resp.isVeryHot());
    }

    @Test
    void openWeatherResponse_isVeryHot_at30() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setTemp(30.0);
        resp.setMain(main);
        assertFalse(resp.isVeryHot());
    }

    @Test
    void openWeatherResponse_isFreezing_below2() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setTemp(1.0);
        resp.setMain(main);
        assertTrue(resp.isFreezing());
    }

    @Test
    void openWeatherResponse_isFreezing_at2() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setTemp(2.0);
        resp.setMain(main);
        assertFalse(resp.isFreezing());
    }

    @Test
    void openWeatherResponse_nullMain_helperMethods() {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        // main is null
        assertFalse(resp.isHighHumidity());
        assertFalse(resp.isVeryHot());
        assertFalse(resp.isFreezing());
    }

    // ========================================================================
    // 2. TrefleDetailResponse
    // ========================================================================

    @Test
    void trefleDetailResponse_allFieldsCovered() {
        TrefleDetailResponse resp = new TrefleDetailResponse();

        TrefleDetailResponse.TreflePlantDetail detail = new TrefleDetailResponse.TreflePlantDetail();
        detail.setId(42);
        detail.setCommonName("Rose");
        detail.setSlug("rosa");
        detail.setScientificName("Rosa gallica");
        detail.setFamily("Rosaceae");
        detail.setGenus("Rosa");
        detail.setImageUrl("https://img.example.com/rose.jpg");
        detail.setYear(1753);
        detail.setAuthor("L.");
        detail.setBibliography("Sp. Pl.");
        detail.setFamilyCommonName("Rose family");

        assertEquals(42, detail.getId());
        assertEquals("Rose", detail.getCommonName());
        assertEquals("rosa", detail.getSlug());
        assertEquals("Rosa gallica", detail.getScientificName());
        assertEquals("Rosaceae", detail.getFamily());
        assertEquals("Rosa", detail.getGenus());
        assertEquals("https://img.example.com/rose.jpg", detail.getImageUrl());
        assertEquals(1753, detail.getYear());
        assertEquals("L.", detail.getAuthor());
        assertEquals("Sp. Pl.", detail.getBibliography());
        assertEquals("Rose family", detail.getFamilyCommonName());

        TrefleDetailResponse.MainSpecies ms = new TrefleDetailResponse.MainSpecies();
        ms.setSlug("rosa-gallica");
        ms.setCommonName("French Rose");
        ms.setScientificName("Rosa gallica");
        assertEquals("rosa-gallica", ms.getSlug());
        assertEquals("French Rose", ms.getCommonName());
        assertEquals("Rosa gallica", ms.getScientificName());

        detail.setMainSpecies(ms);
        assertSame(ms, detail.getMainSpecies());

        resp.setData(detail);
        assertSame(detail, resp.getData());
    }

    // ========================================================================
    // 3. TrefleSearchResponse
    // ========================================================================

    @Test
    void trefleSearchResponse_allFieldsCovered() {
        TrefleSearchResponse resp = new TrefleSearchResponse();

        TrefleSearchResponse.TreflePlantSummary summary = new TrefleSearchResponse.TreflePlantSummary();
        summary.setId(10);
        summary.setCommonName("Sunflower");
        summary.setSlug("helianthus-annuus");
        summary.setScientificName("Helianthus annuus");
        summary.setFamily("Asteraceae");
        summary.setGenus("Helianthus");
        summary.setImageUrl("https://img.example.com/sunflower.jpg");
        summary.setYear(1753);
        summary.setAuthor("L.");
        summary.setFamilyCommonName("Daisy family");

        assertEquals(10, summary.getId());
        assertEquals("Sunflower", summary.getCommonName());
        assertEquals("helianthus-annuus", summary.getSlug());
        assertEquals("Helianthus annuus", summary.getScientificName());
        assertEquals("Asteraceae", summary.getFamily());
        assertEquals("Helianthus", summary.getGenus());
        assertEquals("https://img.example.com/sunflower.jpg", summary.getImageUrl());
        assertEquals(1753, summary.getYear());
        assertEquals("L.", summary.getAuthor());
        assertEquals("Daisy family", summary.getFamilyCommonName());

        resp.setData(List.of(summary));
        assertEquals(1, resp.getData().size());

        TrefleSearchResponse.Meta meta = new TrefleSearchResponse.Meta();
        meta.setTotal(100);
        assertEquals(100, meta.getTotal());

        resp.setMeta(meta);
        assertSame(meta, resp.getMeta());
    }

    // ========================================================================
    // 4. PerenualDetailsResponse
    // ========================================================================

    @Test
    void perenualDetailsResponse_publicFields() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.id = 1;
        resp.commonName = "Snake Plant";
        resp.scientificName = List.of("Dracaena trifasciata");
        resp.cycle = "Perennial";
        resp.watering = "Minimum";
        resp.sunlight = List.of("part shade");
        resp.careLevel = "Low";
        resp.description = "A hardy succulent.";

        assertEquals(1, resp.id);
        assertEquals("Snake Plant", resp.commonName);
        assertEquals("Dracaena trifasciata", resp.scientificName.get(0));
        assertEquals("Perennial", resp.cycle);
        assertEquals("Minimum", resp.watering);
        assertEquals("part shade", resp.sunlight.get(0));
        assertEquals("Low", resp.careLevel);
        assertEquals("A hardy succulent.", resp.description);

        PerenualDetailsResponse.DefaultImage img = new PerenualDetailsResponse.DefaultImage();
        img.thumbnail = "thumb.jpg";
        img.regularUrl = "regular.jpg";
        img.originalUrl = "original.jpg";
        assertEquals("thumb.jpg", img.thumbnail);
        assertEquals("regular.jpg", img.regularUrl);
        assertEquals("original.jpg", img.originalUrl);
        resp.defaultImage = img;

        PerenualDetailsResponse.WateringBenchmark wb = new PerenualDetailsResponse.WateringBenchmark();
        wb.value = "7-10";
        wb.unit = "days";
        assertEquals("7-10", wb.value);
        assertEquals("days", wb.unit);
        resp.wateringBenchmark = wb;
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_benchmarkRange() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.wateringBenchmark = new PerenualDetailsResponse.WateringBenchmark();
        resp.wateringBenchmark.value = "7-10";
        // (7 + 10) / 2 = 8
        assertEquals(8, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_singleValue() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.wateringBenchmark = new PerenualDetailsResponse.WateringBenchmark();
        resp.wateringBenchmark.value = "5";
        assertEquals(5, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_invalidBenchmark() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.wateringBenchmark = new PerenualDetailsResponse.WateringBenchmark();
        resp.wateringBenchmark.value = "not-a-number";
        resp.watering = "frequent";
        // Should fall through to watering frequency
        assertEquals(3, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_nullBenchmark_frequent() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.watering = "Frequent";
        assertEquals(3, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_nullBenchmark_average() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.watering = "Average";
        assertEquals(7, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_nullBenchmark_minimum() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.watering = "Minimum";
        assertEquals(14, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_nullBenchmark_none() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.watering = "None";
        assertEquals(30, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_nullBenchmark_unknown() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        resp.watering = "SomeUnknownValue";
        assertEquals(7, resp.getRecommendedIntervalDays());
    }

    @Test
    void perenualDetailsResponse_getRecommendedIntervalDays_nullWatering() {
        PerenualDetailsResponse resp = new PerenualDetailsResponse();
        // Both benchmark and watering are null -> default 7
        assertEquals(7, resp.getRecommendedIntervalDays());
    }

    // ========================================================================
    // 5. PerenualSearchResponse
    // ========================================================================

    @Test
    void perenualSearchResponse_publicFields() {
        PerenualSearchResponse resp = new PerenualSearchResponse();
        resp.to = 30;
        resp.total = 100;

        PerenualSearchResponse.PerenualSpecies species = new PerenualSearchResponse.PerenualSpecies();
        species.id = 5;
        species.commonName = "Aloe Vera";
        species.scientificName = List.of("Aloe vera");
        species.cycle = "Perennial";
        species.watering = "Minimum";
        species.sunlight = List.of("Full sun");

        PerenualSearchResponse.PerenualSpecies.DefaultImage img =
                new PerenualSearchResponse.PerenualSpecies.DefaultImage();
        img.thumbnail = "aloe_thumb.jpg";
        img.regularUrl = "aloe_regular.jpg";
        assertEquals("aloe_thumb.jpg", img.thumbnail);
        assertEquals("aloe_regular.jpg", img.regularUrl);
        species.defaultImage = img;

        resp.data = List.of(species);

        assertEquals(30, resp.to);
        assertEquals(100, resp.total);
        assertEquals(1, resp.data.size());
        assertEquals(5, resp.data.get(0).id);
        assertEquals("Aloe Vera", resp.data.get(0).commonName);
        assertEquals("Aloe vera", resp.data.get(0).scientificName.get(0));
        assertEquals("Perennial", resp.data.get(0).cycle);
        assertEquals("Minimum", resp.data.get(0).watering);
        assertEquals("Full sun", resp.data.get(0).sunlight.get(0));
        assertNotNull(resp.data.get(0).defaultImage);
    }

    // ========================================================================
    // 6. SpeciesDetailDTO
    // ========================================================================

    @Test
    void speciesDetailDTO_gettersSetters() {
        SpeciesDetailDTO dto = new SpeciesDetailDTO();
        UUID id = UUID.randomUUID();
        dto.setId(id);
        dto.setTrefleId(42);
        dto.setSlug("rosa");
        dto.setCommonName("Rose");
        dto.setScientificName("Rosa gallica");
        dto.setFamily("Rosaceae");
        dto.setGenus("Rosa");
        dto.setImageUrl("https://img.example.com/rose.jpg");
        dto.setYear(1753);
        dto.setAuthor("L.");
        dto.setBibliography("Sp. Pl.");
        dto.setFamilyCommonName("Rose family");

        assertEquals(id, dto.getId());
        assertEquals(42, dto.getTrefleId());
        assertEquals("rosa", dto.getSlug());
        assertEquals("Rose", dto.getCommonName());
        assertEquals("Rosa gallica", dto.getScientificName());
        assertEquals("Rosaceae", dto.getFamily());
        assertEquals("Rosa", dto.getGenus());
        assertEquals("https://img.example.com/rose.jpg", dto.getImageUrl());
        assertEquals(1753, dto.getYear());
        assertEquals("L.", dto.getAuthor());
        assertEquals("Sp. Pl.", dto.getBibliography());
        assertEquals("Rose family", dto.getFamilyCommonName());
    }

    // ========================================================================
    // 7. CareRecommendationDTO
    // ========================================================================

    @Test
    void careRecommendationDTO_getRecommendationMessage_allFields() {
        CareRecommendationDTO dto = new CareRecommendationDTO(
                "Frequent", 3, List.of("Full sun", "Part shade"), "Low",
                "A great plant.", "img.jpg");

        String msg = dto.getRecommendationMessage();
        assertTrue(msg.contains("Arrosage: Fr\u00e9quent (tous les 3 jours)"));
        assertTrue(msg.contains("Exposition: Full sun, Part shade"));
        assertTrue(msg.contains("Niveau de soin: Facile"));
    }

    @Test
    void careRecommendationDTO_getRecommendationMessage_average_medium() {
        CareRecommendationDTO dto = new CareRecommendationDTO(
                "Average", 7, List.of("Part shade"), "Medium",
                null, null);

        String msg = dto.getRecommendationMessage();
        assertTrue(msg.contains("Arrosage: Moyen"));
        assertTrue(msg.contains("Niveau de soin: Moyen"));
    }

    @Test
    void careRecommendationDTO_getRecommendationMessage_minimum_high() {
        CareRecommendationDTO dto = new CareRecommendationDTO(
                "Minimum", 14, null, "High",
                null, null);

        String msg = dto.getRecommendationMessage();
        assertTrue(msg.contains("Peu fr\u00e9quent"));
        assertTrue(msg.contains("Difficile"));
        assertFalse(msg.contains("Exposition:"));
    }

    @Test
    void careRecommendationDTO_getRecommendationMessage_none() {
        CareRecommendationDTO dto = new CareRecommendationDTO(
                "None", 30, List.of(), null,
                null, null);

        String msg = dto.getRecommendationMessage();
        assertTrue(msg.contains("Tr\u00e8s rare"));
        // Empty sunlight list -> no exposition
        assertFalse(msg.contains("Exposition:"));
        // Null careLevel -> no "Niveau de soin"
        assertFalse(msg.contains("Niveau de soin"));
    }

    @Test
    void careRecommendationDTO_getRecommendationMessage_unknownValues() {
        CareRecommendationDTO dto = new CareRecommendationDTO(
                "CustomWater", 5, List.of("Shade"), "CustomLevel",
                null, null);

        String msg = dto.getRecommendationMessage();
        // Unknown watering -> returns the raw string
        assertTrue(msg.contains("CustomWater"));
        // Unknown care level -> returns the raw string
        assertTrue(msg.contains("CustomLevel"));
    }

    @Test
    void careRecommendationDTO_getRecommendationMessage_nullWatering() {
        CareRecommendationDTO dto = new CareRecommendationDTO(
                null, 7, null, null,
                null, null);

        String msg = dto.getRecommendationMessage();
        // Null wateringFrequency -> no "Arrosage:" section
        assertFalse(msg.contains("Arrosage:"));
        assertTrue(msg.isEmpty());
    }

    @Test
    void careRecommendationDTO_fromPerenualDetails() {
        PerenualDetailsResponse details = new PerenualDetailsResponse();
        details.watering = "Average";
        details.wateringBenchmark = new PerenualDetailsResponse.WateringBenchmark();
        details.wateringBenchmark.value = "5-9";
        details.sunlight = List.of("Full sun");
        details.careLevel = "Medium";
        details.description = "Nice plant";

        PerenualDetailsResponse.DefaultImage img = new PerenualDetailsResponse.DefaultImage();
        img.regularUrl = "http://example.com/img.jpg";
        details.defaultImage = img;

        CareRecommendationDTO dto = CareRecommendationDTO.from(details);

        assertEquals("Average", dto.wateringFrequency());
        assertEquals(7, dto.recommendedIntervalDays()); // (5+9)/2
        assertEquals(List.of("Full sun"), dto.sunlight());
        assertEquals("Medium", dto.careLevel());
        assertEquals("Nice plant", dto.description());
        assertEquals("http://example.com/img.jpg", dto.imageUrl());
    }

    @Test
    void careRecommendationDTO_fromPerenualDetails_nullImage() {
        PerenualDetailsResponse details = new PerenualDetailsResponse();
        details.watering = "Minimum";
        details.sunlight = null;
        details.careLevel = null;
        details.description = null;
        details.defaultImage = null;

        CareRecommendationDTO dto = CareRecommendationDTO.from(details);

        assertEquals("Minimum", dto.wateringFrequency());
        assertEquals(14, dto.recommendedIntervalDays());
        assertNull(dto.sunlight());
        assertNull(dto.careLevel());
        assertNull(dto.description());
        assertNull(dto.imageUrl());
    }

    // ========================================================================
    // 8. Record DTOs
    // ========================================================================

    @Test
    void tokenResponse_constructAndAccessors() {
        TokenResponse tr = new TokenResponse("mytoken", "Bearer", 3600);
        assertEquals("mytoken", tr.token());
        assertEquals("Bearer", tr.type());
        assertEquals(3600, tr.expiresIn());
    }

    @Test
    void tokenResponse_bearerFactory() {
        TokenResponse tr = TokenResponse.bearer("jwt-abc", 7200);
        assertEquals("jwt-abc", tr.token());
        assertEquals("Bearer", tr.type());
        assertEquals(7200, tr.expiresIn());
    }

    @Test
    void houseResponseDTO_construct() {
        UUID id = UUID.randomUUID();
        OffsetDateTime now = OffsetDateTime.now();
        HouseResponseDTO dto = new HouseResponseDTO(
                id, "My House", "ABC123", 3, 2, true, "OWNER", now);

        assertEquals(id, dto.id());
        assertEquals("My House", dto.name());
        assertEquals("ABC123", dto.inviteCode());
        assertEquals(3, dto.memberCount());
        assertEquals(2, dto.roomCount());
        assertTrue(dto.isActive());
        assertEquals("OWNER", dto.role());
        assertEquals(now, dto.joinedAt());
    }

    @Test
    void plantDetailDTO_constructWithInnerRecords() {
        UUID plantId = UUID.randomUUID();
        UUID roomId = UUID.randomUUID();
        UUID speciesId = UUID.randomUUID();
        UUID logId = UUID.randomUUID();
        OffsetDateTime now = OffsetDateTime.now();
        LocalDate today = LocalDate.now();

        PlantDetailDTO.RoomInfo room = new PlantDetailDTO.RoomInfo(roomId, "Salon", "LIVING_ROOM");
        assertEquals(roomId, room.id());
        assertEquals("Salon", room.name());
        assertEquals("LIVING_ROOM", room.type());

        PlantDetailDTO.SpeciesInfo species = new PlantDetailDTO.SpeciesInfo(
                speciesId, 42, "Rose", "Rosa gallica", "Rosaceae", "Rosa",
                "https://img.example.com/rose.jpg");
        assertEquals(speciesId, species.id());
        assertEquals(42, species.trefleId());
        assertEquals("Rose", species.commonName());
        assertEquals("Rosa gallica", species.scientificName());
        assertEquals("Rosaceae", species.family());
        assertEquals("Rosa", species.genus());
        assertEquals("https://img.example.com/rose.jpg", species.imageUrl());

        PlantDetailDTO.CareLogInfo log = new PlantDetailDTO.CareLogInfo(
                logId, "WATERING", "Watered well", now, "Lucas");
        assertEquals(logId, log.id());
        assertEquals("WATERING", log.action());
        assertEquals("Watered well", log.notes());
        assertEquals(now, log.performedAt());
        assertEquals("Lucas", log.performedByName());

        PlantDetailDTO dto = new PlantDetailDTO(
                plantId, "My Rose", "photo.jpg", today, now, 7, today.plusDays(7),
                false, "Some notes", false, false, false, Exposure.SUN, now,
                room, species, null, new BigDecimal("15.5"), List.of(log), true);

        assertEquals(plantId, dto.id());
        assertEquals("My Rose", dto.nickname());
        assertEquals("photo.jpg", dto.photoUrl());
        assertEquals(today, dto.acquiredAt());
        assertEquals(now, dto.lastWatered());
        assertEquals(7, dto.wateringIntervalDays());
        assertEquals(today.plusDays(7), dto.nextWateringDate());
        assertFalse(dto.needsWatering());
        assertEquals("Some notes", dto.notes());
        assertFalse(dto.isSick());
        assertFalse(dto.isWilted());
        assertFalse(dto.needsRepotting());
        assertEquals(Exposure.SUN, dto.exposure());
        assertEquals(now, dto.createdAt());
        assertNotNull(dto.room());
        assertNotNull(dto.species());
        assertNull(dto.customSpecies());
        assertEquals(new BigDecimal("15.5"), dto.potDiameterCm());
        assertEquals(1, dto.recentCareLogs().size());
        assertTrue(dto.canManage());
    }

    @Test
    void roomResponseDTO_construct() {
        UUID roomId = UUID.randomUUID();
        UUID plantId = UUID.randomUUID();
        OffsetDateTime now = OffsetDateTime.now();

        RoomResponseDTO.PlantSummaryDTO plant = new RoomResponseDTO.PlantSummaryDTO(
                plantId, "Fern", "fern.jpg", "Boston Fern",
                true, LocalDate.now(), false, false, true);
        assertEquals(plantId, plant.id());
        assertEquals("Fern", plant.nickname());
        assertEquals("fern.jpg", plant.photoUrl());
        assertEquals("Boston Fern", plant.speciesCommonName());
        assertTrue(plant.needsWatering());
        assertNotNull(plant.nextWateringDate());
        assertFalse(plant.isSick());
        assertFalse(plant.isWilted());
        assertTrue(plant.needsRepotting());

        RoomResponseDTO dto = new RoomResponseDTO(
                roomId, "Bedroom", RoomType.BEDROOM, 1, now, List.of(plant));
        assertEquals(roomId, dto.id());
        assertEquals("Bedroom", dto.name());
        assertEquals(RoomType.BEDROOM, dto.type());
        assertEquals(1, dto.plantCount());
        assertEquals(now, dto.createdAt());
        assertEquals(1, dto.plants().size());
    }

    // ========================================================================
    // Helper methods
    // ========================================================================

    private OpenWeatherResponse buildWeatherResponse(String weatherMain) {
        OpenWeatherResponse resp = new OpenWeatherResponse();
        OpenWeatherResponse.Weather w = new OpenWeatherResponse.Weather();
        w.setMain(weatherMain);
        resp.setWeather(List.of(w));
        return resp;
    }
}
