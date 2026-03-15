package com.plantmanager.dto.weather;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Response DTO for OpenWeatherMap current weather API.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class OpenWeatherResponse {

    private List<Weather> weather;
    private Main main;
    private Wind wind;
    private Rain rain;
    private Clouds clouds;
    private String name;

    public List<Weather> getWeather() {
        return weather;
    }

    public void setWeather(List<Weather> weather) {
        this.weather = weather;
    }

    public Main getMain() {
        return main;
    }

    public void setMain(Main main) {
        this.main = main;
    }

    public Wind getWind() {
        return wind;
    }

    public void setWind(Wind wind) {
        this.wind = wind;
    }

    public Rain getRain() {
        return rain;
    }

    public void setRain(Rain rain) {
        this.rain = rain;
    }

    public Clouds getClouds() {
        return clouds;
    }

    public void setClouds(Clouds clouds) {
        this.clouds = clouds;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Weather {
        private int id;
        private String main;
        private String description;
        private String icon;

        public int getId() {
            return id;
        }

        public void setId(int id) {
            this.id = id;
        }

        public String getMain() {
            return main;
        }

        public void setMain(String main) {
            this.main = main;
        }

        public String getDescription() {
            return description;
        }

        public void setDescription(String description) {
            this.description = description;
        }

        public String getIcon() {
            return icon;
        }

        public void setIcon(String icon) {
            this.icon = icon;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Main {
        private double temp;

        @JsonProperty("feels_like")
        private double feelsLike;

        @JsonProperty("temp_min")
        private double tempMin;

        @JsonProperty("temp_max")
        private double tempMax;

        private int humidity;

        public double getTemp() {
            return temp;
        }

        public void setTemp(double temp) {
            this.temp = temp;
        }

        public double getFeelsLike() {
            return feelsLike;
        }

        public void setFeelsLike(double feelsLike) {
            this.feelsLike = feelsLike;
        }

        public double getTempMin() {
            return tempMin;
        }

        public void setTempMin(double tempMin) {
            this.tempMin = tempMin;
        }

        public double getTempMax() {
            return tempMax;
        }

        public void setTempMax(double tempMax) {
            this.tempMax = tempMax;
        }

        public int getHumidity() {
            return humidity;
        }

        public void setHumidity(int humidity) {
            this.humidity = humidity;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Wind {
        private double speed;

        public double getSpeed() {
            return speed;
        }

        public void setSpeed(double speed) {
            this.speed = speed;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Rain {
        @JsonProperty("1h")
        private Double oneHour;

        @JsonProperty("3h")
        private Double threeHours;

        public Double getOneHour() {
            return oneHour;
        }

        public void setOneHour(Double oneHour) {
            this.oneHour = oneHour;
        }

        public Double getThreeHours() {
            return threeHours;
        }

        public void setThreeHours(Double threeHours) {
            this.threeHours = threeHours;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Clouds {
        private int all;

        public int getAll() {
            return all;
        }

        public void setAll(int all) {
            this.all = all;
        }
    }

    /**
     * Check if it's currently raining.
     */
    public boolean isRaining() {
        if (weather == null || weather.isEmpty()) return false;
        String weatherMain = weather.get(0).getMain();
        return "Rain".equalsIgnoreCase(weatherMain) || "Drizzle".equalsIgnoreCase(weatherMain)
                || "Thunderstorm".equalsIgnoreCase(weatherMain);
    }

    /**
     * Get rain amount in mm (last 1h or 3h).
     */
    public double getRainMm() {
        if (rain == null) return 0;
        if (rain.getOneHour() != null) return rain.getOneHour();
        if (rain.getThreeHours() != null) return rain.getThreeHours();
        return 0;
    }

    /**
     * Check if humidity is very high (>80%).
     */
    public boolean isHighHumidity() {
        return main != null && main.getHumidity() > 80;
    }

    /**
     * Check if it's very hot (>30C).
     */
    public boolean isVeryHot() {
        return main != null && main.getTemp() > 30;
    }

    /**
     * Check if it's freezing (<2C).
     */
    public boolean isFreezing() {
        return main != null && main.getTemp() < 2;
    }
}
