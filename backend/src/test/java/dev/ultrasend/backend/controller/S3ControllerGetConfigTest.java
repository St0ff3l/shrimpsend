package dev.ultrasend.backend.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.ultrasend.backend.dto.S3ConfigResponse;
import dev.ultrasend.backend.dto.S3StorageMode;
import dev.ultrasend.backend.security.JwtAuthFilter;
import dev.ultrasend.backend.service.S3Service;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = S3Controller.class)
@Import(GlobalExceptionHandler.class)
@AutoConfigureMockMvc(addFilters = false)
class S3ControllerGetConfigTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private S3Service s3Service;

    @MockBean
    private JwtAuthFilter jwtAuthFilter;

    @Test
    void getConfigDoesNotExposeSecretAccessKey() throws Exception {
        when(s3Service.getConfig(1L)).thenReturn(S3ConfigResponse.builder()
                .mode(S3StorageMode.CUSTOM)
                .configured(true)
                .hostedAvailable(false)
                .customSaved(true)
                .endpoint("https://s3.example.com")
                .region("cn-east-1")
                .bucket("my-bucket")
                .accessKeyId("AKIAEXAMPLE")
                .pathStyleAccessEnabled(true)
                .build());

        MvcResult result = mockMvc.perform(get("/api/s3/config")
                        .principal(new UsernamePasswordAuthenticationToken("1", null, List.of())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.secretAccessKey").doesNotExist())
                .andExpect(jsonPath("$.accessKeyId").value("AKIAEXAMPLE"))
                .andReturn();

        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        assertFalse(json.has("secretAccessKey"));
    }
}
