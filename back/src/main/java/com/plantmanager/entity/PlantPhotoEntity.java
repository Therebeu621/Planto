package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "plant_photo")
public class PlantPhotoEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plant_id", nullable = false)
    public UserPlantEntity plant;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "uploaded_by", nullable = false)
    public UserEntity uploadedBy;

    @Column(name = "photo_path", nullable = false, columnDefinition = "TEXT")
    public String photoPath;

    @Column(length = 200)
    public String caption;

    @Column(name = "is_primary")
    public boolean isPrimary = false;

    @Column(name = "uploaded_at")
    public OffsetDateTime uploadedAt;

    public static List<PlantPhotoEntity> findByPlant(UUID plantId) {
        return list("plant.id = ?1 order by isPrimary desc, uploadedAt desc", plantId);
    }

    public static PlantPhotoEntity findPrimary(UUID plantId) {
        return find("plant.id = ?1 and isPrimary = true", plantId).firstResult();
    }

    public static PlantPhotoEntity findByPlantAndPath(UUID plantId, String photoPath) {
        return find("plant.id = ?1 and photoPath = ?2", plantId, photoPath).firstResult();
    }

    public static long countByPlant(UUID plantId) {
        return count("plant.id", plantId);
    }

    @PrePersist
    void onCreate() {
        if (uploadedAt == null) uploadedAt = OffsetDateTime.now();
    }
}
