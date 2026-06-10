-- Per-user DEK column for S3 SK and enc:u:v1: message text.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS data_encryption_key_enc VARCHAR(512) DEFAULT NULL;
