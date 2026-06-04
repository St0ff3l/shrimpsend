package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.ReleasePresignRequest;
import dev.ultrasend.backend.dto.ReleasePresignResponse;
import dev.ultrasend.backend.dto.ReleaseServerUploadResponse;
import dev.ultrasend.backend.service.AdminAuthService;
import dev.ultrasend.backend.service.ReleaseAssetStorageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@RestController
@RequestMapping("/api/admin/release")
@RequiredArgsConstructor
public class AdminReleaseController {

    private final AdminAuthService adminAuthService;
    private final ReleaseAssetStorageService releaseAssetStorageService;

    @PostMapping("/presign")
    public ResponseEntity<ReleasePresignResponse> presign(Authentication auth,
                                                          @Valid @RequestBody ReleasePresignRequest req) {
        adminAuthService.requireAdmin(auth);
        ReleasePresignResponse res = releaseAssetStorageService.presignPut(
                req.getPlatform(),
                req.getBuildNumber(),
                req.getFileName(),
                req.getContentType());
        return ResponseEntity.ok(res);
    }

    /**
     * 先上传到应用服务器，再由服务端写入 COS（避免浏览器直连 COS 的 CORS）。
     */
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ReleaseServerUploadResponse> upload(Authentication auth,
                                                              @RequestParam("file") MultipartFile file,
                                                              @RequestParam("platform") String platform,
                                                              @RequestParam("buildNumber") int buildNumber,
                                                              @RequestParam(value = "fileName", required = false) String fileName)
            throws IOException {
        adminAuthService.requireAdmin(auth);
        ReleaseServerUploadResponse res = releaseAssetStorageService.uploadViaServer(
                file, platform, buildNumber, fileName);
        return ResponseEntity.ok(res);
    }
}
