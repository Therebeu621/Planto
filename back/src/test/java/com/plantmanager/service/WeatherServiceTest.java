package com.plantmanager.service;

import com.plantmanager.client.OpenWeatherClient;
import com.plantmanager.dto.weather.OpenWeatherResponse;
import com.plantmanager.dto.weather.PlantCareSheetDTO;
import com.plantmanager.dto.weather.WeatherWateringAdviceDTO;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@QuarkusTest
public class WeatherServiceTest {

    @Inject
    WeatherService weatherService;

    @InjectMock
    @RestClient
    OpenWeatherClient weatherClient;

    @BeforeEach
    void setUp() {
        Mockito.reset(weatherClient);
    }

    // ===== Helper methods to build OpenWeatherResponse =====

    private OpenWeatherResponse buildResponse(double temp, int humidity, String weatherMain,
                                               String description, Double rainMm, Double windSpeed) {
        OpenWeatherResponse response = new OpenWeatherResponse();

        OpenWeatherResponse.Main main = new OpenWeatherResponse.Main();
        main.setTemp(temp);
        main.setHumidity(humidity);
        response.setMain(main);

        OpenWeatherResponse.Weather w = new OpenWeatherResponse.Weather();
        w.setMain(weatherMain);
        w.setDescription(description);
        response.setWeather(List.of(w));

        response.setName("Paris");

        if (rainMm != null) {
            OpenWeatherResponse.Rain rain = new OpenWeatherResponse.Rain();
            rain.setOneHour(rainMm);
            response.setRain(rain);
        }

        if (windSpeed != null) {
            OpenWeatherResponse.Wind wind = new OpenWeatherResponse.Wind();
            wind.setSpeed(windSpeed);
            response.setWind(wind);
        }

        return response;
    }

    private void mockWeather(OpenWeatherResponse response) {
        when(weatherClient.getCurrentWeather(anyString(), anyString(), eq("metric"), eq("fr")))
                .thenReturn(response);
    }

    // ===== 1. getWateringAdvice with rain (isRaining=true, rainMm > 5) =====

    @Test
    void testWateringAdvice_withHeavyRain() {
        OpenWeatherResponse response = buildResponse(15.0, 60, "Rain", "forte pluie", 8.0, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertTrue(advice.shouldSkipOutdoorWatering());
        assertEquals(1.5, advice.intervalAdjustmentFactor());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("pleut")));
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Pluie abondante")));
        assertEquals(8.0, advice.rainMm());
    }

    // ===== 1b. getWateringAdvice with light rain (isRaining=true, rainMm <= 5) =====

    @Test
    void testWateringAdvice_withLightRain() {
        OpenWeatherResponse response = buildResponse(15.0, 60, "Drizzle", "bruine", 2.0, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertTrue(advice.shouldSkipOutdoorWatering());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("pleut")));
        // No "Pluie abondante" for light rain
        assertFalse(advice.advices().stream().anyMatch(a -> a.contains("Pluie abondante")));
    }

    // ===== 2. getWateringAdvice with high humidity (>80%) =====

    @Test
    void testWateringAdvice_withHighHumidity() {
        OpenWeatherResponse response = buildResponse(20.0, 85, "Clouds", "couvert", null, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertEquals(85, advice.humidity());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Humidité élevée")));
        assertEquals("Réduire l'arrosage (humidité élevée)", advice.indoorAdvice());
        assertEquals(1.3, advice.intervalAdjustmentFactor());
    }

    // ===== 3. getWateringAdvice with low humidity (<30%) =====

    @Test
    void testWateringAdvice_withLowHumidity() {
        OpenWeatherResponse response = buildResponse(20.0, 25, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertEquals(25, advice.humidity());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Air très sec")));
        assertEquals("Augmenter l'arrosage et vaporiser (air sec)", advice.indoorAdvice());
        assertEquals(0.8, advice.intervalAdjustmentFactor());
    }

    // ===== 4. getWateringAdvice with very hot (>30C) =====

    @Test
    void testWateringAdvice_withVeryHot() {
        OpenWeatherResponse response = buildResponse(35.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertEquals(35.0, advice.temperature());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Canicule")));
        assertEquals("Augmenter la fréquence d'arrosage (chaleur)", advice.indoorAdvice());
        assertEquals(0.7, advice.intervalAdjustmentFactor());
    }

    // ===== 5. getWateringAdvice with freezing (<2C) =====

    @Test
    void testWateringAdvice_withFreezing() {
        OpenWeatherResponse response = buildResponse(-3.0, 50, "Snow", "neige", null, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertEquals(-3.0, advice.temperature());
        assertTrue(advice.shouldSkipOutdoorWatering());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Gel")));
        assertEquals("Réduire l'arrosage (froid)", advice.indoorAdvice());
        assertEquals(1.5, advice.intervalAdjustmentFactor());
    }

    // ===== 6. getWateringAdvice with strong wind (>30 km/h) =====

    @Test
    void testWateringAdvice_withStrongWind() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, 45.0);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Vent fort")));
    }

    // ===== 7. getWateringAdvice with normal conditions =====

    @Test
    void testWateringAdvice_normalConditions() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, 5.0);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertFalse(advice.shouldSkipOutdoorWatering());
        assertEquals(1.0, advice.intervalAdjustmentFactor());
        assertEquals("Arrosage normal", advice.indoorAdvice());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Conditions météo normales")));
    }

    // ===== 8. getWateringAdvice when API key not configured =====

    @Test
    void testWateringAdvice_apiKeyNotConfigured() {
        // When no API key is configured, getCurrentWeather returns empty
        // and buildDefaultAdvice is called. We simulate this by making the client throw.
        when(weatherClient.getCurrentWeather(anyString(), anyString(), eq("metric"), eq("fr")))
                .thenThrow(new RuntimeException("API error"));

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        // When API fails, we get default seasonal advice
        assertNotNull(advice);
        assertFalse(advice.advices().isEmpty());
        assertFalse(advice.shouldSkipOutdoorWatering());
    }

    // ===== 9. generateCareSheet with known species (Monstera) =====

    @Test
    void testGenerateCareSheet_knownSpecies_monstera() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Monstera", "Paris");

        assertEquals("Monstera", sheet.speciesName());
        assertEquals("Tropicale", sheet.category());
        assertEquals(7, sheet.wateringIntervalDays());
        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.careSummary().contains("Monstera"));
        assertTrue(sheet.careSummary().contains("Tropicale"));
        assertFalse(sheet.seasonalAdvice().isEmpty());
        assertFalse(sheet.commonProblems().isEmpty());
    }

    // ===== 10. generateCareSheet with unknown species =====

    @Test
    void testGenerateCareSheet_unknownSpecies() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Plante Inconnue XYZ", "Paris");

        assertEquals("Plante Inconnue XYZ", sheet.speciesName());
        assertEquals("Plante d'intérieur", sheet.category());
        assertEquals(7, sheet.wateringIntervalDays());
        assertTrue(sheet.careSummary().contains("générique"));
    }

    // ===== 11a. generateCareSheet with tropical category =====

    @Test
    void testGenerateCareSheet_tropical() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Calathea", "Paris");

        assertEquals("Tropicale", sheet.category());
        assertEquals(4, sheet.seasonalAdvice().size());
        assertTrue(sheet.seasonalAdvice().stream().anyMatch(s -> s.wateringAdjustment().contains("vaporisation")));
        assertTrue(sheet.commonProblems().stream().anyMatch(p -> p.contains("cochenilles")));
    }

    // ===== 11b. generateCareSheet with succulent category =====

    @Test
    void testGenerateCareSheet_succulent() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Cactus", "Paris");

        assertEquals("Succulente", sheet.category());
        assertEquals(4, sheet.seasonalAdvice().size());
        assertTrue(sheet.seasonalAdvice().stream().anyMatch(s -> s.careNotes().contains("Quasi aucun") || s.wateringAdjustment().contains("Quasi aucun")));
        assertTrue(sheet.commonProblems().stream().anyMatch(p -> p.contains("pourriture")));
    }

    // ===== 11c. generateCareSheet with flowering category =====

    @Test
    void testGenerateCareSheet_flowering() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Orchidee", "Paris");

        assertEquals("Floraison", sheet.category());
        assertEquals(4, sheet.seasonalAdvice().size());
        assertTrue(sheet.seasonalAdvice().stream().anyMatch(s -> s.careNotes().contains("floraison")));
        assertTrue(sheet.commonProblems().stream().anyMatch(p -> p.contains("floraison")));
    }

    // ===== 11d. generateCareSheet with herb category =====

    @Test
    void testGenerateCareSheet_herb() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Basilic", "Paris");

        assertEquals("Herbe aromatique", sheet.category());
        assertEquals(4, sheet.seasonalAdvice().size());
        assertTrue(sheet.seasonalAdvice().stream().anyMatch(s -> s.careNotes().contains("Récolter") || s.careNotes().contains("Semis")));
        assertTrue(sheet.commonProblems().stream().anyMatch(p -> p.contains("Pucerons")));
    }

    // ===== 11e. generateCareSheet with default/general category =====

    @Test
    void testGenerateCareSheet_defaultCategory() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        // "Ficus" is in DEFAULTS with category "general", but hasInfoFor returns true
        // Use a completely unknown species to exercise the default seasonal advice branch
        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Plante Bizarre", "Paris");

        assertEquals("Plante d'intérieur", sheet.category());
        assertEquals(4, sheet.seasonalAdvice().size());
        assertTrue(sheet.seasonalAdvice().stream().anyMatch(s -> s.careNotes().contains("Repos végétatif")));
        assertTrue(sheet.commonProblems().stream().anyMatch(p -> p.contains("Moisissure")));
    }

    // ===== 12. getAdjustedWateringInterval =====

    @Test
    void testGetAdjustedWateringInterval_normalConditions() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        int adjusted = weatherService.getAdjustedWateringInterval(7, "Paris");

        // adjustmentFactor = 1.0, so 7 * 1.0 = 7
        assertEquals(7, adjusted);
    }

    @Test
    void testGetAdjustedWateringInterval_hotWeather() {
        OpenWeatherResponse response = buildResponse(35.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        int adjusted = weatherService.getAdjustedWateringInterval(7, "Paris");

        // adjustmentFactor = 0.7, so 7 * 0.7 = 4.9 -> rounded to 5
        assertEquals(5, adjusted);
    }

    @Test
    void testGetAdjustedWateringInterval_freezing() {
        OpenWeatherResponse response = buildResponse(-3.0, 50, "Snow", "neige", null, null);
        mockWeather(response);

        int adjusted = weatherService.getAdjustedWateringInterval(7, "Paris");

        // adjustmentFactor = 1.5, so 7 * 1.5 = 10.5 -> rounded to 11, capped at 14
        assertEquals(11, adjusted);
    }

    @Test
    void testGetAdjustedWateringInterval_neverLessThanOne() {
        OpenWeatherResponse response = buildResponse(35.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        int adjusted = weatherService.getAdjustedWateringInterval(1, "Paris");

        // adjustmentFactor = 0.7, so 1 * 0.7 = 0.7 -> rounded to 1, min is 1
        assertEquals(1, adjusted);
    }

    @Test
    void testGetAdjustedWateringInterval_neverMoreThanDouble() {
        OpenWeatherResponse response = buildResponse(-3.0, 50, "Snow", "neige", null, null);
        mockWeather(response);

        int adjusted = weatherService.getAdjustedWateringInterval(3, "Paris");

        // adjustmentFactor = 1.5, so 3 * 1.5 = 4.5 -> rounded to 5, capped at 6 (3*2)
        assertEquals(5, adjusted);
    }

    // ===== 13. buildWeatherCareAdvice for each category with rain =====

    @Test
    void testGenerateCareSheet_weatherAdvice_rain() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Rain", "pluie", 3.0, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Monstera", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("Pluie détectée"));
    }

    // ===== 13b. buildWeatherCareAdvice for tropical with hot =====

    @Test
    void testGenerateCareSheet_weatherAdvice_hotTropical() {
        OpenWeatherResponse response = buildResponse(35.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Monstera", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("vaporisez les feuilles"));
    }

    // ===== 13c. buildWeatherCareAdvice for succulent with hot =====

    @Test
    void testGenerateCareSheet_weatherAdvice_hotSucculent() {
        OpenWeatherResponse response = buildResponse(35.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Cactus", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("succulentes résistent bien"));
    }

    // ===== 13d. buildWeatherCareAdvice for default category with hot =====

    @Test
    void testGenerateCareSheet_weatherAdvice_hotDefault() {
        OpenWeatherResponse response = buildResponse(35.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Ficus", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("arrosez plus fréquemment"));
    }

    // ===== 13e. buildWeatherCareAdvice for tropical with freezing =====

    @Test
    void testGenerateCareSheet_weatherAdvice_freezingTropical() {
        OpenWeatherResponse response = buildResponse(-3.0, 50, "Snow", "neige", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Monstera", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("ATTENTION gel"));
    }

    // ===== 13f. buildWeatherCareAdvice for succulent with freezing =====

    @Test
    void testGenerateCareSheet_weatherAdvice_freezingSucculent() {
        OpenWeatherResponse response = buildResponse(-3.0, 50, "Snow", "neige", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Cactus", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("protégez du gel"));
    }

    // ===== 13g. buildWeatherCareAdvice for default category with freezing =====

    @Test
    void testGenerateCareSheet_weatherAdvice_freezingDefault() {
        OpenWeatherResponse response = buildResponse(-3.0, 50, "Snow", "neige", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Ficus", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("protégez les plantes sensibles"));
    }

    // ===== 13h. buildWeatherCareAdvice with high humidity =====

    @Test
    void testGenerateCareSheet_weatherAdvice_highHumidity() {
        OpenWeatherResponse response = buildResponse(20.0, 90, "Clouds", "couvert", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Monstera", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("Humidité élevée"));
        assertTrue(sheet.weatherAdvice().contains("moisissure"));
    }

    // ===== 13i. buildWeatherCareAdvice normal conditions =====

    @Test
    void testGenerateCareSheet_weatherAdvice_normalConditions() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Monstera", "Paris");

        assertNotNull(sheet.weatherAdvice());
        assertTrue(sheet.weatherAdvice().contains("Conditions normales"));
    }

    // ===== generateCareSheet without weather data =====

    @Test
    void testGenerateCareSheet_noWeatherData() {
        when(weatherClient.getCurrentWeather(anyString(), anyString(), eq("metric"), eq("fr")))
                .thenThrow(new RuntimeException("API error"));

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Monstera", "Paris");

        assertEquals("Monstera", sheet.speciesName());
        assertEquals("Tropicale", sheet.category());
        assertNull(sheet.weatherAdvice());
        assertNotNull(sheet.careSummary());
    }

    // ===== Combined conditions: rain + high humidity =====

    @Test
    void testWateringAdvice_rainAndHighHumidity() {
        OpenWeatherResponse response = buildResponse(15.0, 90, "Rain", "pluie", 8.0, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertTrue(advice.shouldSkipOutdoorWatering());
        // Rain sets factor to 1.5, high humidity doesn't override because factor != 1.0
        assertEquals(1.5, advice.intervalAdjustmentFactor());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("pleut")));
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Humidité élevée")));
    }

    // ===== Combined conditions: hot + low humidity =====

    @Test
    void testWateringAdvice_hotAndLowHumidity() {
        OpenWeatherResponse response = buildResponse(35.0, 25, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        // Low humidity sets factor to 0.8, hot sets factor to min(0.8, 0.7) = 0.7
        assertEquals(0.7, advice.intervalAdjustmentFactor());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Air très sec")));
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("Canicule")));
    }

    // ===== Thunderstorm also counts as raining =====

    @Test
    void testWateringAdvice_thunderstorm() {
        OpenWeatherResponse response = buildResponse(20.0, 70, "Thunderstorm", "orage", 10.0, null);
        mockWeather(response);

        WeatherWateringAdviceDTO advice = weatherService.getWateringAdvice("Paris");

        assertTrue(advice.shouldSkipOutdoorWatering());
        assertTrue(advice.advices().stream().anyMatch(a -> a.contains("pleut")));
    }

    // ===== buildWeatherCareAdvice with flowering category hot =====

    @Test
    void testGenerateCareSheet_weatherAdvice_hotFlowering() {
        OpenWeatherResponse response = buildResponse(35.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Orchidee", "Paris");

        assertNotNull(sheet.weatherAdvice());
        // Flowering is not tropical or succulent, so falls into else branch
        assertTrue(sheet.weatherAdvice().contains("arrosez plus fréquemment"));
    }

    // ===== buildWeatherCareAdvice with herb category freezing =====

    @Test
    void testGenerateCareSheet_weatherAdvice_freezingHerb() {
        OpenWeatherResponse response = buildResponse(-3.0, 50, "Snow", "neige", null, null);
        mockWeather(response);

        PlantCareSheetDTO sheet = weatherService.generateCareSheet("Basilic", "Paris");

        assertNotNull(sheet.weatherAdvice());
        // Herb is not tropical or succulent, so falls into else branch
        assertTrue(sheet.weatherAdvice().contains("protégez les plantes sensibles"));
    }

    // ===== Care level and frequency labels via generateCareSheet =====

    @Test
    void testGenerateCareSheet_careLevelAndFrequency() {
        OpenWeatherResponse response = buildResponse(20.0, 50, "Clear", "ciel dégagé", null, null);
        mockWeather(response);

        // Basilic: intervalDays=2 -> "Fréquent", careLevel="Attention requise"
        PlantCareSheetDTO basilSheet = weatherService.generateCareSheet("Basilic", "Paris");
        assertEquals("Fréquent", basilSheet.wateringFrequency());
        assertEquals("Attention requise", basilSheet.careLevel());

        // Monstera: intervalDays=7 -> "Moyen", careLevel="Moyen"
        PlantCareSheetDTO monsteraSheet = weatherService.generateCareSheet("Monstera", "Paris");
        assertEquals("Moyen", monsteraSheet.wateringFrequency());
        assertEquals("Moyen", monsteraSheet.careLevel());

        // Orchidee: intervalDays=10 -> "Peu fréquent", careLevel="Moyen"
        PlantCareSheetDTO orchidSheet = weatherService.generateCareSheet("Orchidee", "Paris");
        assertEquals("Peu fréquent", orchidSheet.wateringFrequency());
        assertEquals("Moyen", orchidSheet.careLevel());

        // Cactus: intervalDays=21 -> "Rare", careLevel="Facile"
        PlantCareSheetDTO cactusSheet = weatherService.generateCareSheet("Cactus", "Paris");
        assertEquals("Rare", cactusSheet.wateringFrequency());
        assertEquals("Facile", cactusSheet.careLevel());
    }
}
