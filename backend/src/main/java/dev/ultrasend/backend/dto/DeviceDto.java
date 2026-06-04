package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceDto {

    /** 1–999 short display id per user; null for LAN-only / non-cloud rows. */
    private Integer displayCode;

    private String deviceId;
    private String name;
    private String platform;
    private String lanHttpUrl;
    /** Epoch millis; null if never seen. Used by client to show online (e.g. within last 2 min). */
    private Long lastSeen;
    /** Aggregated device presence: online/offline. */
    private String presenceStatus;
    /** Epoch millis for the last presence status transition. */
    private Long presenceUpdatedAt;
}
