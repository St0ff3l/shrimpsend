package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.ChangePasswordRequest;
import dev.ultrasend.backend.dto.UserProfileResponse;
import dev.ultrasend.backend.entity.EmailVerificationCode;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final VerificationCodeService verificationCodeService;

    public UserProfileResponse getProfile(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        return UserProfileResponse.builder()
                .userId(user.getId().toString())
                .email(user.getEmail())
                .username(user.getUsername())
                .build();
    }

    public void sendChangePasswordCode(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        verificationCodeService.sendCode(user.getEmail(), EmailVerificationCode.TYPE_CHANGE_PASSWORD);
        log.info("sendChangePasswordCode success userId={}", userId);
    }

    @Transactional
    public void changePassword(Long userId, ChangePasswordRequest req) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        boolean valid = verificationCodeService.verify(
                user.getEmail(), EmailVerificationCode.TYPE_CHANGE_PASSWORD, req.getCode());
        if (!valid) {
            throw new IllegalArgumentException("验证码错误或已过期");
        }
        user.setPasswordHash(passwordEncoder.encode(req.getNewPassword()));
        userRepository.save(user);
        log.info("changePassword success userId={}", userId);
    }

    public void sendDeleteAccountCode(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        verificationCodeService.sendCode(user.getEmail(), EmailVerificationCode.TYPE_DELETE_ACCOUNT);
        log.info("sendDeleteAccountCode success userId={}", userId);
    }

    @Transactional
    public void confirmDeleteAccount(Long userId, String code) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        boolean valid = verificationCodeService.verify(
                user.getEmail(), EmailVerificationCode.TYPE_DELETE_ACCOUNT, code);
        if (!valid) {
            throw new IllegalArgumentException("验证码错误或已过期");
        }
        userRepository.deleteById(userId);
        log.info("confirmDeleteAccount success userId={}", userId);
    }
}
