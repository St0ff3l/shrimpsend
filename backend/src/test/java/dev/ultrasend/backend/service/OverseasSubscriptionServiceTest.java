package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.OverseasBillingProperties;
import dev.ultrasend.backend.entity.MembershipEntitlement;
import dev.ultrasend.backend.entity.MembershipOrderEvent;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.membership.MembershipChannel;
import dev.ultrasend.backend.membership.OverseasMembershipTier;
import dev.ultrasend.backend.repository.MembershipEntitlementRepository;
import dev.ultrasend.backend.repository.MembershipOrderEventRepository;
import dev.ultrasend.backend.repository.MembershipOrderRepository;
import dev.ultrasend.backend.repository.SubscriptionConflictRepository;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OverseasSubscriptionServiceTest {

    @Mock
    private ClusterDeploymentService clusterDeploymentService;
    @Mock
    private HostedQuotaService hostedQuotaService;
    @Mock
    private OverseasBillingProperties overseasBillingProperties;
    @Mock
    private MembershipEntitlementRepository membershipEntitlementRepository;
    @Mock
    private MembershipOrderEventRepository membershipOrderEventRepository;
    @Mock
    private MembershipOrderRepository membershipOrderRepository;
    @Mock
    private SubscriptionConflictRepository subscriptionConflictRepository;
    @Mock
    private UserRepository userRepository;

    private OverseasSubscriptionService service;

    @BeforeEach
    void setUp() {
        service = new OverseasSubscriptionService(
                clusterDeploymentService,
                hostedQuotaService,
                overseasBillingProperties,
                membershipEntitlementRepository,
                membershipOrderEventRepository,
                membershipOrderRepository,
                subscriptionConflictRepository,
                userRepository);
    }

    @Test
    void resolveRcChannelFromStore_mapsPlayStoreToGoogleRc() {
        assertEquals(MembershipChannel.GOOGLE_RC,
                OverseasSubscriptionService.resolveRcChannelFromStore("PLAY_STORE"));
        assertEquals(MembershipChannel.APPLE_RC,
                OverseasSubscriptionService.resolveRcChannelFromStore("APP_STORE"));
    }

    @Test
    void processRevenueCatPayload_refundDowngradesToFree() {
        when(clusterDeploymentService.isOverseasDeployment()).thenReturn(true);
        long userId = 42L;
        User user = User.builder().id(userId).build();
        MembershipEntitlement ent = MembershipEntitlement.builder()
                .user(user)
                .tierCode(OverseasMembershipTier.PLUS.getCode())
                .deviceLimit(6)
                .paymentChannel("APPLE_RC")
                .subscriptionExpiresAt(Instant.now().plusSeconds(86400))
                .build();

        when(membershipOrderEventRepository.existsByProviderAndEventUniqueKey(
                eq("REVENUECAT_OS"), eq("RC_EVT:refund-evt-1"))).thenReturn(false);
        when(membershipEntitlementRepository.findByUserId(userId)).thenReturn(Optional.of(ent));
        when(membershipOrderEventRepository.save(any(MembershipOrderEvent.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(membershipEntitlementRepository.save(any(MembershipEntitlement.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> payload = new HashMap<>();
        Map<String, Object> event = new HashMap<>();
        event.put("id", "refund-evt-1");
        event.put("type", "REFUND");
        event.put("app_user_id", "42");
        event.put("product_id", "shrimpsend_plus_monthly");
        event.put("store", "APP_STORE");
        payload.put("event", event);

        assertTrue(service.processRevenueCatPayload(payload));

        ArgumentCaptor<MembershipEntitlement> captor = ArgumentCaptor.forClass(MembershipEntitlement.class);
        verify(membershipEntitlementRepository).save(captor.capture());
        assertEquals(OverseasMembershipTier.FREE.getCode(), captor.getValue().getTierCode());
        assertEquals("FREE", captor.getValue().getPaymentChannel());
        verify(membershipOrderRepository, never()).save(any());
    }

    @Test
    void normalizeRcProductId_stripsGooglePlayBasePlanSuffix() {
        assertEquals("shrimpsend_plus_monthly",
                OverseasSubscriptionService.normalizeRcProductId("shrimpsend_plus_monthly:default"));
        assertEquals("shrimpsend_plus_monthly",
                OverseasSubscriptionService.normalizeRcProductId("shrimpsend_plus_monthly"));
    }

    @Test
    void processRevenueCatPayload_playStoreProductIdWithBasePlanGrantsSubscription() {
        when(clusterDeploymentService.isOverseasDeployment()).thenReturn(true);
        when(overseasBillingProperties.getRcPlusMonthly()).thenReturn("shrimpsend_plus_monthly");
        long userId = 1L;
        User user = User.builder().id(userId).build();

        when(membershipOrderEventRepository.existsByProviderAndEventUniqueKey(
                eq("REVENUECAT_OS"), eq("RC_EVT:gp-purchase-1"))).thenReturn(false);
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(membershipEntitlementRepository.findByUserId(userId)).thenReturn(Optional.empty());
        when(membershipOrderEventRepository.save(any(MembershipOrderEvent.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(membershipEntitlementRepository.save(any(MembershipEntitlement.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(membershipOrderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> payload = new HashMap<>();
        Map<String, Object> event = new HashMap<>();
        event.put("id", "gp-purchase-1");
        event.put("type", "INITIAL_PURCHASE");
        event.put("app_user_id", "1");
        event.put("product_id", "shrimpsend_plus_monthly:default");
        event.put("store", "PLAY_STORE");
        event.put("expiration_at_ms", Instant.now().plusSeconds(86400 * 30).toEpochMilli());
        payload.put("event", event);

        assertTrue(service.processRevenueCatPayload(payload));

        ArgumentCaptor<MembershipEntitlement> captor = ArgumentCaptor.forClass(MembershipEntitlement.class);
        verify(membershipEntitlementRepository).save(captor.capture());
        assertEquals(OverseasMembershipTier.PLUS.getCode(), captor.getValue().getTierCode());
        assertEquals("GOOGLE_RC", captor.getValue().getPaymentChannel());
        verify(membershipOrderRepository).save(any());
    }

    @Test
    void processRevenueCatPayload_initialPurchaseGrantsSubscription() {
        when(clusterDeploymentService.isOverseasDeployment()).thenReturn(true);
        when(overseasBillingProperties.getRcPlusMonthly()).thenReturn("shrimpsend_plus_monthly");
        long userId = 7L;
        User user = User.builder().id(userId).build();

        when(membershipOrderEventRepository.existsByProviderAndEventUniqueKey(
                eq("REVENUECAT_OS"), eq("RC_EVT:purchase-evt-1"))).thenReturn(false);
        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(membershipEntitlementRepository.findByUserId(userId)).thenReturn(Optional.empty());
        when(membershipOrderEventRepository.save(any(MembershipOrderEvent.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(membershipEntitlementRepository.save(any(MembershipEntitlement.class)))
                .thenAnswer(inv -> inv.getArgument(0));
        when(membershipOrderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> payload = new HashMap<>();
        Map<String, Object> event = new HashMap<>();
        event.put("id", "purchase-evt-1");
        event.put("type", "INITIAL_PURCHASE");
        event.put("app_user_id", "7");
        event.put("product_id", "shrimpsend_plus_monthly");
        event.put("store", "APP_STORE");
        event.put("expiration_at_ms", Instant.now().plusSeconds(86400 * 30).toEpochMilli());
        payload.put("event", event);

        assertTrue(service.processRevenueCatPayload(payload));

        ArgumentCaptor<MembershipEntitlement> captor = ArgumentCaptor.forClass(MembershipEntitlement.class);
        verify(membershipEntitlementRepository).save(captor.capture());
        assertEquals(OverseasMembershipTier.PLUS.getCode(), captor.getValue().getTierCode());
        assertEquals("APPLE_RC", captor.getValue().getPaymentChannel());
        verify(membershipOrderRepository).save(any());
    }
}
