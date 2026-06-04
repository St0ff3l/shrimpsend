package dev.ultrasend.backend.membership;

public enum MembershipOrderStatus {
    CREATED,
    PENDING_PAYMENT,
    PAID,
    GRANTED,
    FAILED,
    CANCELLED
}
