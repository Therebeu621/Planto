package com.plantmanager.entity;

import com.plantmanager.entity.enums.CultureStatus;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "culture_growth_log")
public class CultureGrowthLogEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "culture_id", nullable = false)
    public GardenCultureEntity culture;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public UserEntity user;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "old_status", columnDefinition = "culture_status")
    public CultureStatus oldStatus;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "new_status", nullable = false, columnDefinition = "culture_status")
    public CultureStatus newStatus;

    @Column(name = "height_cm", precision = 6, scale = 1)
    public BigDecimal heightCm;

    @Column(columnDefinition = "TEXT")
    public String notes;

    @Column(name = "photo_path", columnDefinition = "TEXT")
    public String photoPath;

    @Column(name = "logged_at")
    public OffsetDateTime loggedAt;

    public static List<CultureGrowthLogEntity> findByCulture(UUID cultureId) {
        return list("culture.id = ?1 order by loggedAt desc", cultureId);
    }

    @PrePersist
    void onCreate() {
        if (loggedAt == null) loggedAt = OffsetDateTime.now();
    }
}
