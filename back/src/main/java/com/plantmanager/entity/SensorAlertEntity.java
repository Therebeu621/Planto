package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "sensor_alert")
public class SensorAlertEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sensor_id", nullable = false)
    public IotSensorEntity sensor;

    @Column(name = "min_value", precision = 10, scale = 2)
    public BigDecimal minValue;

    @Column(name = "max_value", precision = 10, scale = 2)
    public BigDecimal maxValue;

    @Column(name = "is_active")
    public boolean isActive = true;

    public static List<SensorAlertEntity> findBySensor(UUID sensorId) {
        return list("sensor.id = ?1 and isActive = true", sensorId);
    }
}
