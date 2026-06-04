package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.Message;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {

    List<Message> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);

    List<Message> findByUserIdAndIdLessThanOrderByCreatedAtDesc(Long userId, Long beforeId, Pageable pageable);

    List<Message> findByIdGreaterThanOrderByIdAsc(Long id, Pageable pageable);

    void deleteByIdAndUserId(Long id, Long userId);
}
