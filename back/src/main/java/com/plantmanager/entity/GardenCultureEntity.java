package com.plantmanager.entity;

import com.plantmanager.entity.enums.CultureStatus;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "garden_culture")
public class GardenCultureEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id", nullable = false)
    public HouseEntity house;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    public UserEntity createdBy;

    @Column(name = "plant_name", nullable = false, length = 100)
    public String plantName;

    @Column(length = 100)
    public String variety;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "culture_status")
    public CultureStatus status = CultureStatus.SEMIS;

    @Column(name = "sow_date", nullable = false)
    public LocalDate sowDate;

    @Column(name = "expected_harvest_date")
    public LocalDate expectedHarvestDate;

    @Column(name = "actual_harvest_date")
    public LocalDate actualHarvestDate;

    @Column(name = "harvest_quantity", length = 100)
    public String harvestQuantity;

    @Column(columnDefinition = "TEXT")
    public String notes;

    @Column(name = "row_number")
    public Integer rowNumber;

    @Column(name = "column_number")
    public Integer columnNumber;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    @Column(name = "updated_at")
    public OffsetDateTime updatedAt;

    @OneToMany(mappedBy = "culture", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
    public List<CultureGrowthLogEntity> growthLogs = new ArrayList<>();

    public static List<GardenCultureEntity> findByHouse(UUID houseId) {
        return list("house.id = ?1 order by createdAt desc", houseId);
    }

    public static List<GardenCultureEntity> findActiveByHouse(UUID houseId) {
        return list("house.id = ?1 and status != ?2 order by sowDate desc", houseId, CultureStatus.TERMINE);
    }

    public static List<GardenCultureEntity> findByStatus(UUID houseId, CultureStatus status) {
        return list("house.id = ?1 and status = ?2 order by sowDate desc", houseId, status);
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = OffsetDateTime.now();
        if (updatedAt == null) updatedAt = OffsetDateTime.now();
        if (sowDate == null) sowDate = LocalDate.now();
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}
