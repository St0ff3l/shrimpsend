package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "messages", indexes = @Index(name = "idx_messages_user_created", columnList = "user_id, created_at"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "data", nullable = false, columnDefinition = "MEDIUMTEXT")
    private String data; // JSON envelope; text payload.text may be encrypted.

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) createdAt = Instant.now();
    }
}
