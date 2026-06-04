package dev.ultrasend.backend.dto.centrifugo;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RefreshResultDto {

    /** Unix 秒，连接延长到此时间 */
    @JsonProperty("expire_at")
    private Long expireAt;
}
