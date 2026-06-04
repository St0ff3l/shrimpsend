package dev.ultrasend.backend.service;

import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.Set;

@Service
public class ClusterDeploymentService {

    private static final Set<String> OVERSEAS_PROFILES = Set.of("prod-overseas", "dev-overseas");

    private final Environment environment;

    public ClusterDeploymentService(Environment environment) {
        this.environment = environment;
    }

    /** ShrimpSend overseas cluster (separate DB): production or local {@code dev-overseas}. */
    public boolean isOverseasDeployment() {
        return Arrays.stream(environment.getActiveProfiles()).anyMatch(OVERSEAS_PROFILES::contains);
    }
}
