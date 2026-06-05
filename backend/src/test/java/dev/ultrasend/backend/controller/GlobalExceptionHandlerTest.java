package dev.ultrasend.backend.controller;

import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void jwtExceptionReturns401WithSessionExpiredMessage() {
        ResponseEntity<Map<String, String>> response =
                handler.handleJwtException(new JwtException("JWT signature does not match"));

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
        assertEquals("登录已失效，请重新登录", response.getBody().get("error"));
    }

    @Test
    void runtimeExceptionStillReturns500() {
        ResponseEntity<Map<String, String>> response =
                handler.handleRuntimeException(new RuntimeException("database down"));

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertEquals("database down", response.getBody().get("error"));
    }
}
