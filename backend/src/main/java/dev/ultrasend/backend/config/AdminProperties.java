package dev.ultrasend.backend.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Comma-separated admin emails ({@code app.admin.emails}).
 */
@Getter
@Setter
@ConfigurationProperties(prefix = "app.admin")
public class AdminProperties {

    /**
     * Default matches product requirement; override via {@code APP_ADMIN_EMAILS} in deployment.
     */
    private String emails = "admin@example.com";
}
