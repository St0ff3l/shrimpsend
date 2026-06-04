package dev.ultrasend.backend.service;

import dev.ultrasend.backend.entity.MembershipEntitlement;
import dev.ultrasend.backend.entity.MobileVerificationCode;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.membership.MembershipTier;
import dev.ultrasend.backend.repository.MembershipEntitlementRepository;
import dev.ultrasend.backend.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.sql.DataSource;
import java.time.Instant;

@Service
@Slf4j
public class MembershipMigrationService {

    private final UserRepository userRepository;
    private final MembershipEntitlementRepository membershipEntitlementRepository;
    private final MobileVerificationCodeService mobileVerificationCodeService;
    
    @Value("${app.datasource.sdt.url:}")
    private String sdtUrl;
    
    @Value("${app.datasource.sdt.driver-class-name:com.mysql.cj.jdbc.Driver}")
    private String sdtDriverClassName;
    
    @Value("${app.datasource.sdt.username:}")
    private String sdtUsername;
    
    @Value("${app.datasource.sdt.password:}")
    private String sdtPassword;

    public MembershipMigrationService(
            UserRepository userRepository,
            MembershipEntitlementRepository membershipEntitlementRepository,
            MobileVerificationCodeService mobileVerificationCodeService) {
        this.userRepository = userRepository;
        this.membershipEntitlementRepository = membershipEntitlementRepository;
        this.mobileVerificationCodeService = mobileVerificationCodeService;
    }

    /**
     * 临时创建连接查询闪电藤数据库
     */
    private JdbcTemplate createSdtJdbcTemplate() {
        if (sdtUrl == null || sdtUrl.isEmpty()) {
            throw new IllegalStateException("闪电藤数据库未配置");
        }
        DriverManagerDataSource dataSource = new DriverManagerDataSource();
        dataSource.setDriverClassName(sdtDriverClassName);
        dataSource.setUrl(sdtUrl);
        dataSource.setUsername(sdtUsername);
        dataSource.setPassword(sdtPassword);
        return new JdbcTemplate(dataSource);
    }

    /**
     * 检查闪电藤数据库中该手机号是否为会员且未迁移
     * @return true 如果是会员且未迁移，false 如果不是会员或已迁移
     */
    public boolean checkLightningMember(String mobile) {
        if (sdtUrl == null || sdtUrl.isEmpty()) {
            log.warn("闪电藤数据库未配置，无法检查会员状态 mobile={}", mobile);
            return false;
        }
        
        try {
            JdbcTemplate jdbcTemplate = createSdtJdbcTemplate();
            // 根据环境判断数据库名：本地是 sdt，生产是 sdt_prod
            String dbName = sdtUrl.contains("sdt_prod") ? "sdt_prod" : "sdt";
            // 检查是否为会员且未迁移
            String sql = String.format(
                "SELECT vip_type, migrated_to_ultrasend FROM %s.member_user WHERE mobile = ? AND deleted = 0 LIMIT 1", 
                dbName);
            var results = jdbcTemplate.queryForList(sql, mobile);
            
            if (results.isEmpty()) {
                log.debug("lightning member not found mobile={}", mobile);
                return false;
            }
            
            var result = results.get(0);
            Integer vipType = (Integer) result.get("vip_type");
            // TINYINT(1) 可能被 MySQL JDBC 驱动返回为 Boolean 或 Integer
            Object migratedObj = result.get("migrated_to_ultrasend");
            boolean notMigrated;
            if (migratedObj instanceof Boolean) {
                notMigrated = !((Boolean) migratedObj);
            } else if (migratedObj instanceof Integer) {
                notMigrated = ((Integer) migratedObj) == 0;
            } else {
                notMigrated = migratedObj == null;
            }
            
            // 必须是会员（vip_type = 1）且未迁移（migrated_to_ultrasend = 0）
            boolean isMember = vipType != null && vipType == 1;
            
            if (isMember && !notMigrated) {
                log.warn("lightning member already migrated mobile={}", mobile);
            }
            
            return isMember && notMigrated;
        } catch (Exception e) {
            log.error("check lightning member failed mobile={}", mobile, e);
            return false;
        }
    }
    
    /**
     * 检查闪电藤数据库中该手机号是否已迁移
     * @return true 如果已迁移，false 如果未迁移或查询失败
     */
    private boolean isLightningMemberMigrated(String mobile) {
        if (sdtUrl == null || sdtUrl.isEmpty()) {
            return false;
        }
        
        try {
            JdbcTemplate jdbcTemplate = createSdtJdbcTemplate();
            String dbName = sdtUrl.contains("sdt_prod") ? "sdt_prod" : "sdt";
            String sql = String.format(
                "SELECT migrated_to_ultrasend FROM %s.member_user WHERE mobile = ? AND deleted = 0 LIMIT 1", 
                dbName);
            var results = jdbcTemplate.queryForList(sql, mobile);
            
            if (results.isEmpty()) {
                return false;
            }
            
            // TINYINT(1) 可能被 MySQL JDBC 驱动返回为 Boolean 或 Integer
            Object migratedObj = results.get(0).get("migrated_to_ultrasend");
            if (migratedObj instanceof Boolean) {
                return (Boolean) migratedObj;
            } else if (migratedObj instanceof Integer) {
                return ((Integer) migratedObj) == 1;
            } else {
                return false;
            }
        } catch (Exception e) {
            log.error("check lightning member migrated status failed mobile={}", mobile, e);
            return false;
        }
    }

    /**
     * 验证手机号和验证码（仅验证，不授予会员）
     */
    public boolean verifyMobile(Long userId, String mobile, String code) {
        // 1. 验证短信验证码
        if (!mobileVerificationCodeService.verify(mobile, MobileVerificationCode.TYPE_MIGRATION, code)) {
            throw new IllegalArgumentException("验证码错误或已过期");
        }

        // 2. 检查是否已迁移
        if (isLightningMemberMigrated(mobile)) {
            throw new IllegalArgumentException("该手机号已经迁移过，不能重复迁移");
        }

        // 3. 查询闪电藤数据库确认会员身份
        if (!checkLightningMember(mobile)) {
            throw new IllegalArgumentException("该手机号在闪电藤中不是会员或已迁移，无法迁移");
        }

        return true;
    }

    /**
     * 授予Pro会员（在用户确认后调用）
     */
    @Transactional
    public void grantProMembership(Long userId, String mobile) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));

        // 检查当前用户是否已经迁移过（防重复）
        if (user.getVerifiedMobile() != null && !user.getVerifiedMobile().isBlank()) {
            throw new IllegalArgumentException("您已经迁移过会员，不能重复迁移");
        }

        // 检查该手机号是否已被其他用户验证过（防重复使用）
        boolean mobileUsed = userRepository.existsByVerifiedMobileAndIdNot(mobile, userId);
        if (mobileUsed) {
            throw new IllegalArgumentException("该手机号已被其他用户使用，不能重复使用");
        }

        // 查询闪电藤数据库确认会员身份
        if (!checkLightningMember(mobile)) {
            throw new IllegalArgumentException("该手机号在闪电藤中不是会员或已迁移，无法迁移");
        }

        // 原子性地标记闪电藤用户为已迁移（防止并发）
        boolean marked = markLightningMemberAsMigrated(mobile);
        if (!marked) {
            // 标记失败，说明已被其他用户迁移
            throw new IllegalArgumentException("该手机号已经迁移过，不能重复迁移");
        }

        // 授予Pro会员（创建MembershipEntitlement或升级现有）
        MembershipEntitlement entitlement = membershipEntitlementRepository.findByUserId(userId)
                .orElse(MembershipEntitlement.builder()
                        .user(user)
                        .tierCode(MembershipTier.FREE.getCode())
                        .deviceLimit(3)
                        .addonPacks(0)
                        .isLifetime(true)
                        .effectiveAt(Instant.now())
                        .updatedAt(Instant.now())
                        .build());

        MembershipTier currentTier = MembershipTier.fromCode(entitlement.getTierCode());
        MembershipTier proTier = MembershipTier.PRO;

        // 如果当前档位低于Pro，则升级到Pro
        if (currentTier.getRank() < proTier.getRank()) {
            entitlement.setTierCode(proTier.getCode());
            int addon = entitlement.getAddonPacks() != null ? entitlement.getAddonPacks() : 0;
            entitlement.setDeviceLimit(proTier.getDeviceLimit() + addon * 5);
            entitlement.setIsLifetime(true);
            entitlement.setEffectiveAt(Instant.now());
        }
        entitlement.setUpdatedAt(Instant.now());
        membershipEntitlementRepository.save(entitlement);

        // 标记手机号为已验证
        user.setVerifiedMobile(mobile);
        user.setMobileMigrationVerifiedAt(Instant.now());
        userRepository.save(user);

        log.info("membership migration granted userId={} mobile={} tier=PRO", userId, mobile);
    }

    /**
     * 原子性地标记闪电藤用户为已迁移
     * 使用 UPDATE ... WHERE 条件确保原子性，防止并发迁移
     * @param mobile 手机号
     * @return true 如果成功标记，false 如果已被其他用户迁移
     */
    private boolean markLightningMemberAsMigrated(String mobile) {
        if (sdtUrl == null || sdtUrl.isEmpty()) {
            log.warn("闪电藤数据库未配置，无法标记迁移状态 mobile={}", mobile);
            return false;
        }
        
        try {
            JdbcTemplate jdbcTemplate = createSdtJdbcTemplate();
            String dbName = sdtUrl.contains("sdt_prod") ? "sdt_prod" : "sdt";
            // 使用原子操作：只有 migrated_to_ultrasend = 0 的记录才会被更新
            String sql = String.format(
                "UPDATE %s.member_user SET migrated_to_ultrasend = 1, migrated_at = NOW(3) WHERE mobile = ? AND deleted = 0 AND migrated_to_ultrasend = 0",
                dbName);
            int affectedRows = jdbcTemplate.update(sql, mobile);
            
            if (affectedRows > 0) {
                log.info("lightning member marked as migrated mobile={}", mobile);
                return true;
            } else {
                log.warn("lightning member already migrated or not found mobile={}", mobile);
                return false;
            }
        } catch (Exception e) {
            log.error("mark lightning member as migrated failed mobile={}", mobile, e);
            return false;
        }
    }
}
