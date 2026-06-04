package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.User;

import java.util.Optional;

public interface UserRepository extends org.springframework.data.jpa.repository.JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    boolean existsByVerifiedMobileAndIdNot(String verifiedMobile, Long id);
}
