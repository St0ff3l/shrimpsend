package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "mobile_verification_codes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MobileVerificationCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 11)
    private String mobile;

    @Column(nullable = false, length = 6)
    private String code;

    @Column(nullable = false, length = 20)
    private String type;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(nullable = false)
    @Builder.Default
    private Boolean used = false;

    public static final String TYPE_MIGRATION = "MIGRATION";
}
