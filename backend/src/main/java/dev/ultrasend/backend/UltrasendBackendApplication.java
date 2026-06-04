package dev.ultrasend.backend;

import dev.ultrasend.backend.config.HostedS3Properties;
import dev.ultrasend.backend.config.OverseasBillingProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
@EnableConfigurationProperties({ HostedS3Properties.class, OverseasBillingProperties.class })
public class UltrasendBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(UltrasendBackendApplication.class, args);
    }
}
