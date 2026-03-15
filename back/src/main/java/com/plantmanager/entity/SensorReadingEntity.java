package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "sensor_reading")
public class SensorReadingEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sensor_id", nullable = false)
    public IotSensorEntity sensor;

    @Column(nullable = false, precision = 10, scale = 2)
    public BigDecimal value;

    @Column(nullable = false, length = 20)
    public String unit;

    @Column(name = "recorded_at")
    public OffsetDateTime recordedAt;

    public static List<SensorReadingEntity> findBySensor(UUID sensorId, int limit) {
        return find("sensor.id = ?1 order by recordedAt desc", sensorId)
                .page(0, limit).list();
    }

    public static List<SensorReadingEntity> findBySensorBetween(UUID sensorId, OffsetDateTime from, OffsetDateTime to) {
        return list("sensor.id = ?1 and recordedAt >= ?2 and recordedAt <= ?3 order by recordedAt asc",
                sensorId, from, to);
    }

    public static SensorReadingEntity findLatestBySensor(UUID sensorId) {
        return find("sensor.id = ?1 order by recordedAt desc", sensorId).firstResult();
    }

    @PrePersist
    void onCreate() {
        if (recordedAt == null) recordedAt = OffsetDateTime.now();
    }
}
