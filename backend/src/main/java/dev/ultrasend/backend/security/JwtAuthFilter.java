package dev.ultrasend.backend.security;

import dev.ultrasend.backend.entity.Device;
import dev.ultrasend.backend.repository.DeviceRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;
import java.util.Optional;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthFilter extends OncePerRequestFilter {

    private final AppJwtService jwtService;
    private final DeviceRepository deviceRepository;

    private static boolean isPaymentWebhookPath(String path) {
        return "/api/membership/alipay/notify".equals(path)
                || "/api/membership/revenuecat/webhook".equals(path)
                || "/api/membership/stripe/webhook".equals(path);
    }

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain) throws ServletException, IOException {
        String path = request.getRequestURI();
        if (isPaymentWebhookPath(path)) {
            filterChain.doFilter(request, response);
            return;
        }
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            log.trace("JWT no Bearer path={}", request.getRequestURI());
            filterChain.doFilter(request, response);
            return;
        }
        String token = authHeader.substring(7);
        try {
            AppJwtService.ParsedAuthToken parsed = jwtService.parseAccessToken(token);
            String userId = parsed.userId();
            if (parsed.deviceId() != null && parsed.deviceSessionVersion() != null) {
                Optional<Device> od = deviceRepository.findByUser_IdAndDeviceIdAndActiveTrue(
                        Long.parseLong(userId), parsed.deviceId());
                if (od.isEmpty()) {
                    log.warn("JWT device inactive or missing userId={} deviceId={}", userId, parsed.deviceId());
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    return;
                }
                Device d = od.get();
                if (d.getSessionVersion() != parsed.deviceSessionVersion()) {
                    log.warn("JWT device session mismatch userId={} deviceId={}", userId, parsed.deviceId());
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    return;
                }
            }
            UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                    userId,
                    null,
                    Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER"))
            );
            auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
            SecurityContextHolder.getContext().setAuthentication(auth);
            log.debug("JWT authenticated userId={} path={}", userId, request.getRequestURI());
        } catch (Exception e) {
            log.warn("JWT invalid token path={} error={}", request.getRequestURI(), e.getMessage());
        }
        filterChain.doFilter(request, response);
    }
}
