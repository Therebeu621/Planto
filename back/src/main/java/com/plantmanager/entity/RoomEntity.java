package com.plantmanager.entity;

import com.plantmanager.entity.enums.RoomType;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Room entity representing a room/location in a house.
 * Plants are assigned to rooms.
 * Maps to the 'room' table.
 */
@Entity
@Table(name = "room", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"house_id", "name"})
})
public class RoomEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "house_id", nullable = false)
    public HouseEntity house;

    @Column(nullable = false, length = 100)
    public String name;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(columnDefinition = "room_type")
    public RoomType type = RoomType.OTHER;

    @Column(name = "created_at")
    public OffsetDateTime createdAt;

    // One-to-Many: Room has many Plants
    @OneToMany(mappedBy = "room", fetch = FetchType.LAZY)
    public List<UserPlantEntity> plants = new ArrayList<>();

    // ===== Static finder methods =====

    public static List<RoomEntity> findByHouse(UUID houseId) {
        return list("house.id", houseId);
    }

    public static long countByHouse(UUID houseId) {
        return count("house.id", houseId);
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
        if (type == null) {
            type = RoomType.OTHER;
        }
    }
}
