package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "email_verification_codes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmailVerificationCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String email;

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

    public static final String TYPE_REGISTER = "REGISTER";
    public static final String TYPE_LOGIN = "LOGIN";
    public static final String TYPE_DELETE_ACCOUNT = "DELETE_ACCOUNT";
    public static final String TYPE_CHANGE_PASSWORD = "CHANGE_PASSWORD";
}
