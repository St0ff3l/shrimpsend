package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.SendMessageRequest;
import dev.ultrasend.backend.service.MessageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/messages")
@RequiredArgsConstructor
@Slf4j
public class MessageController {

    private final MessageService messageService;

    @PostMapping("/send")
    public ResponseEntity<Void> send(Authentication auth, @RequestBody SendMessageRequest req) {
        if (auth == null || !auth.isAuthenticated()) {
            log.warn("messages/send unauthenticated 401");
            return ResponseEntity.status(401).build();
        }
        String userId = (String) auth.getPrincipal();
        Object data = req.getData();
        log.info("messages/send userId={}", userId);
        messageService.send(userId, data);
        log.debug("messages/send ok userId={}", userId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/thread")
    public ResponseEntity<Void> deleteThread(
            Authentication auth,
            @RequestParam String threadKey) {
        if (auth == null || !auth.isAuthenticated()) {
            return ResponseEntity.status(401).build();
        }
        if (threadKey == null || threadKey.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        Long userId = Long.parseLong((String) auth.getPrincipal());
        messageService.deleteMessagesByThreadKey(userId, threadKey);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(Authentication auth, @PathVariable Long id) {
        if (auth == null || !auth.isAuthenticated()) {
            return ResponseEntity.status(401).build();
        }
        Long userId = Long.parseLong((String) auth.getPrincipal());
        messageService.deleteMessage(userId, id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/history")
    public ResponseEntity<List<Map<String, Object>>> history(
            Authentication auth,
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(required = false) Long before,
            @RequestParam(required = false) String threadKey) {
        if (auth == null || !auth.isAuthenticated()) {
            return ResponseEntity.status(401).build();
        }
        Long userId = Long.parseLong((String) auth.getPrincipal());
        int safeLimit = Math.min(Math.max(1, limit), 100);
        List<Map<String, Object>> list = messageService.getHistory(userId, safeLimit, before, threadKey);
        return ResponseEntity.ok(list);
    }

    @GetMapping("/search")
    public ResponseEntity<List<Map<String, Object>>> search(
            Authentication auth,
            @RequestParam String q,
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(required = false) Long before,
            @RequestParam(required = false) String threadKey) {
        if (auth == null || !auth.isAuthenticated()) {
            return ResponseEntity.status(401).build();
        }
        log.info("messages/search disabled; cloud content search is no longer supported");
        return ResponseEntity.status(410).body(List.of());
    }
}
