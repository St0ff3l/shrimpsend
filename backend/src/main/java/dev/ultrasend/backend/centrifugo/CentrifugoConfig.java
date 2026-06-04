package dev.ultrasend.backend.centrifugo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class CentrifugoConfig {

    @Value("${centrifugo.url}")
    private String centrifugoUrl;

    @Value("${centrifugo.http-api-key}")
    private String apiKey;

    @Bean
    public WebClient centrifugoWebClient(WebClient.Builder builder) {
        return builder
                .baseUrl(centrifugoUrl)
                .defaultHeader("X-API-Key", apiKey)
                .defaultHeader("Content-Type", "application/json")
                .build();
    }
}
