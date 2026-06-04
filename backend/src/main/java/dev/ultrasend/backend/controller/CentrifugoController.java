package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.CentrifugoTokenResponse;
import dev.ultrasend.backend.centrifugo.CentrifugoTokenService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/centrifugo")
@RequiredArgsConstructor
@Slf4j
public class CentrifugoController {

    private final CentrifugoTokenService centrifugoTokenService;

    @GetMapping("/token")
    public ResponseEntity<CentrifugoTokenResponse> getToken(Authentication auth) {
        if (auth == null || !auth.isAuthenticated()) {
            log.warn("centrifugo/token unauthenticated 401");
            return ResponseEntity.status(401).build();
        }
        String userId = (String) auth.getPrincipal();
        log.info("centrifugo/token userId={}", userId);
        CentrifugoTokenResponse tokens = centrifugoTokenService.createTokens(userId);
        log.debug("centrifugo/token ok userId={} channel={}", userId, tokens.getChannel());
        return ResponseEntity.ok(tokens);
    }
}
