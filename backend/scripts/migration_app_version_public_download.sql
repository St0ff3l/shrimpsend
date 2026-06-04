-- Public web download links (mainland / overseas), separate from OTA artifact URLs.
ALTER TABLE app_version
    ADD COLUMN IF NOT EXISTS web_published BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS public_mac_url_mainland VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_win_url_mainland VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_apk_url_mainland VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_ios_store_url_mainland VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_mac_url_overseas VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_win_url_overseas VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_google_play_url_overseas VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_app_store_url_overseas VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS public_apk_url_overseas VARCHAR(1024);
