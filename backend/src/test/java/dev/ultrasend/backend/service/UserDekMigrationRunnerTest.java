package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.env.Environment;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserDekMigrationRunnerTest {

    private static final byte[] KEK = "01234567890123456789012345678901".getBytes(StandardCharsets.UTF_8);

    @Mock
    private UserRepository userRepository;
    @Mock
    private Environment environment;

    private UserDataEncryptionProperties properties;
    private UserDataEncryptionService userDataEncryption;
    private UserDekMigrationRunner runner;

    @BeforeEach
    void setUp() {
        properties = new UserDataEncryptionProperties();
        properties.setKekBase64(Base64.getEncoder().encodeToString(KEK));
        userDataEncryption = new UserDataEncryptionService(properties, userRepository, environment);
        userDataEncryption.init();
        runner = new UserDekMigrationRunner(properties, userRepository, userDataEncryption);
    }

    @Test
    void shouldRunWhenAnyUserDataMigrationFlagEnabled() {
        properties.setMigrateUserDekOnStartup(false);
        properties.setMigrateS3OnStartup(false);
        properties.setMigrateMessagesOnStartup(false);
        assertFalse(runner.shouldRun());

        properties.setMigrateS3OnStartup(true);
        assertTrue(runner.shouldRun());
    }

    @Test
    void backfillMissingUserDeksInitializesWrappedDek() {
        properties.setMigrateUserDekOnStartup(true);
        User user = User.builder().id(5L).email("a@b.com").build();
        when(userRepository.findWithoutDekAfterId(eq(0L), any()))
                .thenReturn(List.of(user));
        when(userRepository.findWithoutDekAfterId(eq(5L), any()))
                .thenReturn(List.of());
        when(userRepository.findById(5L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        runner.backfillMissingUserDeks();

        assertNotNull(user.getDataEncryptionKeyEnc());
        assertTrue(user.getDataEncryptionKeyEnc().startsWith(UserDataEncryptionService.PREFIX_KEK));
    }
}
