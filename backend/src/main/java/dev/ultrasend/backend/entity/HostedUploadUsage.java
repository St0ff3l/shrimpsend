package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "hosted_upload_usage", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "usage_month"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HostedUploadUsage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** UTC calendar month {@code yyyy-MM}; DB column {@code usage_month} (MySQL reserves {@code YEAR}). */
    @Column(name = "usage_month", nullable = false, length = 7)
    private String yearMonth;

    @Column(name = "upload_bytes", nullable = false)
    @Builder.Default
    private Long uploadBytes = 0L;
}
