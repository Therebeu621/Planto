package com.plantmanager.entity;

import com.plantmanager.entity.enums.SensorType;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "iot_sensor")
public class IotSensorEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id", nullable = false)
    public HouseEntity house;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plant_id")
    public UserPlantEntity plant;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "sensor_type", nullable = false, columnDefinition = "sensor_type")
    public SensorType sensorType;

    @Column(name = "device_id", nullable = false, length = 100)
    public String deviceId;

    @Column(length = 100)
    public String label;

    @Column(name = "is_active")
    public boolean isActive = true;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    public static List<IotSensorEntity> findByHouse(UUID houseId) {
        return list("house.id = ?1 order by createdAt desc", houseId);
    }

    public static List<IotSensorEntity> findByPlant(UUID plantId) {
        return list("plant.id = ?1", plantId);
    }

    public static IotSensorEntity findByDeviceId(String deviceId) {
        return find("deviceId", deviceId).firstResult();
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }
}
