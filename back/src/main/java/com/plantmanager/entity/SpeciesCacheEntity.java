package com.plantmanager.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Species cache entity for Trefle.io data.
 * Stores plant species information locally to reduce API calls.
 * Maps to the 'species_cache' table.
 */
@Entity
@Table(name = "species_cache")
public class SpeciesCacheEntity extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    public UUID id;

    @Column(name = "trefle_id", unique = true, nullable = false)
    public Integer trefleId;

    @Column(unique = true)
    public String slug;

    @Column(name = "common_name")
    public String commonName;

    @Column(name = "scientific_name")
    public String scientificName;

    @Column(length = 100)
    public String family;

    @Column(length = 100)
    public String genus;

    @Column(name = "image_url", columnDefinition = "TEXT")
    public String imageUrl;

    private Integer year;

    @Column(columnDefinition = "TEXT")
    public String bibliography;

    private String author;

    @Column(name = "family_common_name")
    public String familyCommonName;

    @Column(name = "cached_at")
    public OffsetDateTime cachedAt;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "raw_json", columnDefinition = "jsonb")
    public String rawJson;

    public Integer getYear() {
        return year;
    }

    public void setYear(Integer year) {
        this.year = year;
    }

    public String getAuthor() {
        return author;
    }

    public void setAuthor(String author) {
        this.author = author;
    }

    // ===== Static finder methods =====

    public static Optional<SpeciesCacheEntity> findByTrefleId(Integer trefleId) {
        return find("trefleId", trefleId).firstResultOptional();
    }

    public static Optional<SpeciesCacheEntity> findBySlug(String slug) {
        return find("slug", slug).firstResultOptional();
    }

    /**
     * Search by common name with priority sorting.
     * Results starting with the query are returned first.
     */
    public static List<SpeciesCacheEntity> searchByCommonName(String query) {
        String lowerQuery = query.toLowerCase();
        // Get all matching results
        List<SpeciesCacheEntity> results = list(
                "lower(commonName) like ?1 or lower(scientificName) like ?1",
                "%" + lowerQuery + "%");

        // Sort: names starting with query first, then alphabetically
        results.sort((a, b) -> {
            String nameA = a.commonName != null ? a.commonName.toLowerCase() : "";
            String nameB = b.commonName != null ? b.commonName.toLowerCase() : "";
            boolean aStartsWith = nameA.startsWith(lowerQuery);
            boolean bStartsWith = nameB.startsWith(lowerQuery);

            if (aStartsWith && !bStartsWith)
                return -1;
            if (!aStartsWith && bStartsWith)
                return 1;
            return nameA.compareTo(nameB);
        });

        return results;
    }

    public static boolean isCacheValid(SpeciesCacheEntity species, int ttlDays) {
        if (species == null || species.cachedAt == null) {
            return false;
        }
        return species.cachedAt.plusDays(ttlDays).isAfter(OffsetDateTime.now());
    }

    @PrePersist
    void onCreate() {
        if (cachedAt == null) {
            cachedAt = OffsetDateTime.now();
        }
    }
}
