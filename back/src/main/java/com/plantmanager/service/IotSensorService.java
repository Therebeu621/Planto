package com.plantmanager.service;

import com.plantmanager.dto.*;
import com.plantmanager.entity.*;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class IotSensorService {

    @Inject
    FcmService fcmService;

    @Transactional
    public IotSensorDTO createSensor(UUID userId, UUID houseId, CreateSensorDTO dto) {
        verifyMembership(userId, houseId);

        HouseEntity house = HouseEntity.findById(houseId);
        if (house == null) throw new NotFoundException("House not found");

        IotSensorEntity sensor = new IotSensorEntity();
        sensor.house = house;
        sensor.sensorType = dto.sensorType();
        sensor.deviceId = dto.deviceId();
        sensor.label = dto.label();

        if (dto.plantId() != null) {
            UserPlantEntity plant = UserPlantEntity.findById(dto.plantId());
            if (plant != null) sensor.plant = plant;
        }

        sensor.persist();
        return IotSensorDTO.from(sensor);
    }

    public List<IotSensorDTO> getSensorsByHouse(UUID userId, UUID houseId) {
        verifyMembership(userId, houseId);
        return IotSensorEntity.findByHouse(houseId).stream()
                .map(IotSensorDTO::from).toList();
    }

    public List<IotSensorDTO> getSensorsByPlant(UUID userId, UUID plantId) {
        UserPlantEntity plant = UserPlantEntity.findById(plantId);
        if (plant == null) throw new NotFoundException("Plant not found");
        return IotSensorEntity.findByPlant(plantId).stream()
                .map(IotSensorDTO::from).toList();
    }

    @Transactional
    public SensorReadingDTO submitReading(UUID sensorId, SubmitReadingDTO dto) {
        IotSensorEntity sensor = IotSensorEntity.findById(sensorId);
        if (sensor == null) throw new NotFoundException("Sensor not found");

        SensorReadingEntity reading = new SensorReadingEntity();
        reading.sensor = sensor;
        reading.value = dto.value();
        reading.unit = sensor.sensorType.getUnit();
        reading.persist();

        // Check alerts
        List<SensorAlertEntity> alerts = SensorAlertEntity.findBySensor(sensorId);
        for (SensorAlertEntity alert : alerts) {
            boolean triggered = false;
            if (alert.minValue != null && dto.value().compareTo(alert.minValue) < 0) triggered = true;
            if (alert.maxValue != null && dto.value().compareTo(alert.maxValue) > 0) triggered = true;

            if (triggered) {
                String label = sensor.label != null ? sensor.label : sensor.sensorType.getDisplayName();
                fcmService.sendToHouseMembers(
                        sensor.house.id, null,
                        "Alerte capteur",
                        label + ": " + dto.value() + " " + sensor.sensorType.getUnit(),
                        java.util.Map.of("type", "SENSOR_ALERT", "sensorId", sensorId.toString()));
            }
        }

        return SensorReadingDTO.from(reading);
    }

    public List<SensorReadingDTO> getReadings(UUID userId, UUID sensorId, int limit) {
        IotSensorEntity sensor = IotSensorEntity.findById(sensorId);
        if (sensor == null) throw new NotFoundException("Sensor not found");
        verifyMembership(userId, sensor.house.id);

        return SensorReadingEntity.findBySensor(sensorId, limit).stream()
                .map(SensorReadingDTO::from).toList();
    }

    public List<SensorReadingDTO> getReadingsBetween(UUID userId, UUID sensorId,
                                                      OffsetDateTime from, OffsetDateTime to) {
        IotSensorEntity sensor = IotSensorEntity.findById(sensorId);
        if (sensor == null) throw new NotFoundException("Sensor not found");
        verifyMembership(userId, sensor.house.id);

        return SensorReadingEntity.findBySensorBetween(sensorId, from, to).stream()
                .map(SensorReadingDTO::from).toList();
    }

    @Transactional
    public void deleteSensor(UUID userId, UUID sensorId) {
        IotSensorEntity sensor = IotSensorEntity.findById(sensorId);
        if (sensor == null) throw new NotFoundException("Sensor not found");
        verifyMembership(userId, sensor.house.id);
        SensorAlertEntity.delete("sensor.id", sensorId);
        SensorReadingEntity.delete("sensor.id", sensorId);
        sensor.delete();
    }

    private void verifyMembership(UUID userId, UUID houseId) {
        UserHouseEntity membership = UserHouseEntity.findByUserAndHouse(userId, houseId);
        if (membership == null) {
            throw new ForbiddenException("You are not a member of this house");
        }
    }
}
