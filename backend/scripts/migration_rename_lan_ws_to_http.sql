-- Rename lan_ws_url to lan_http_url (WebSocket → HTTP transfer)
ALTER TABLE devices CHANGE COLUMN lan_ws_url lan_http_url VARCHAR(512) DEFAULT NULL COMMENT '局域网 HTTP 传输地址';
