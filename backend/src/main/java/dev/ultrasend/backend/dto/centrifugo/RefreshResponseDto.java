package dev.ultrasend.backend.dto.centrifugo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RefreshResponseDto {

    private RefreshResultDto result;
}
