package dev.ultrasend.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import dev.ultrasend.backend.dto.RefreshRequest;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.service.AuthService;
import dev.ultrasend.backend.service.DeviceService;
import dev.ultrasend.backend.service.VerificationCodeService;
import dev.ultrasend.backend.security.AppJwtService;
import dev.ultrasend.backend.security.JwtAuthFilter;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AuthController.class)
@Import(GlobalExceptionHandler.class)
@AutoConfigureMockMvc(addFilters = false)
@TestPropertySource(properties = "app.cors.allowed-origins=http://localhost:3000")
class AuthControllerRefreshTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AuthService authService;
    @MockBean
    private VerificationCodeService verificationCodeService;
    @MockBean
    private UserRepository userRepository;
    @MockBean
    private DeviceService deviceService;
    @MockBean
    private JwtAuthFilter jwtAuthFilter;
    @MockBean
    private AppJwtService appJwtService;

    @Test
    void refreshInvalidJwtReturns401() throws Exception {
        when(authService.refresh(any())).thenThrow(new JwtException("JWT signature does not match"));

        RefreshRequest req = new RefreshRequest();
        req.setRefreshToken("not-a-valid-jwt");

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("登录已失效，请重新登录"));
    }

    @Test
    void refreshSessionExpiredReturns401() throws Exception {
        when(authService.refresh(any()))
                .thenThrow(new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.UNAUTHORIZED,
                        AuthService.SESSION_EXPIRED_MESSAGE));

        RefreshRequest req = new RefreshRequest();
        req.setRefreshToken("any");

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("登录已失效，请重新登录"));
    }
}
