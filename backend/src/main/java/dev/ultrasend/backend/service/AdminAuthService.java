package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.AdminProperties;
import dev.ultrasend.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminAuthService {

    private final AdminProperties adminProperties;
    private final UserRepository userRepository;

    public void requireAdmin(Authentication auth) {
        if (auth == null || auth.getPrincipal() == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "需要管理员权限");
        }
        Long userId;
        try {
            userId = Long.parseLong(auth.getName());
        } catch (NumberFormatException e) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "需要管理员权限");
        }
        var user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "需要管理员权限"));
        String email = user.getEmail().trim().toLowerCase(Locale.ROOT);
        Set<String> allowed = parseAdminEmails();
        if (!allowed.contains(email)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "需要管理员权限");
        }
    }

    private Set<String> parseAdminEmails() {
        String raw = adminProperties.getEmails();
        if (raw == null || raw.isBlank()) {
            return Set.of();
        }
        return Arrays.stream(raw.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(s -> s.toLowerCase(Locale.ROOT))
                .collect(Collectors.toSet());
    }
}
