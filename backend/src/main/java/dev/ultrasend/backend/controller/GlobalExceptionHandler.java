package dev.ultrasend.backend.controller;

import io.jsonwebtoken.JwtException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, String>> handleBadRequest(IllegalArgumentException e) {
        log.warn("BadRequest: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidationException(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining(", "));
        log.warn("Validation failed: {}", message);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("error", message));
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, String>> handleResponseStatus(ResponseStatusException e) {
        String msg = e.getReason();
        if (msg == null || msg.isBlank()) {
            msg = "Error";
        }
        log.warn("ResponseStatus {}: {}", e.getStatusCode().value(), msg);
        return ResponseEntity.status(e.getStatusCode()).body(Map.of("error", msg));
    }

    @ExceptionHandler(org.springframework.security.core.AuthenticationException.class)
    public ResponseEntity<Map<String, String>> handleUnauthorized() {
        log.warn("Unauthorized");
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "Unauthorized"));
    }

    @ExceptionHandler(JwtException.class)
    public ResponseEntity<Map<String, String>> handleJwtException(JwtException e) {
        log.warn("JWT invalid: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "登录已失效，请重新登录"));
    }

    /**
     * 未单独映射的 {@link RuntimeException}（如短信/第三方服务配置问题），返回与 400 一致的 {@code error} JSON，
     * 便于客户端解析；{@link IllegalArgumentException} 等更具体的类型仍由上方处理器接管。
     */
    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<Map<String, String>> handleRuntimeException(RuntimeException e) {
        log.error("Unhandled runtime exception", e);
        String message = e.getMessage();
        if (message == null || message.isBlank()) {
            message = "服务器错误，请稍后重试";
        }
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", message));
    }
}
