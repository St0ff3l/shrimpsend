package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.User;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends org.springframework.data.jpa.repository.JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    boolean existsByVerifiedMobileAndIdNot(String verifiedMobile, Long id);

    @Query("""
            SELECT u FROM User u
            WHERE u.id > :cursor
              AND (u.dataEncryptionKeyEnc IS NULL OR u.dataEncryptionKeyEnc = '')
            ORDER BY u.id ASC
            """)
    List<User> findWithoutDekAfterId(@Param("cursor") Long cursor, Pageable pageable);
}
