-- 清理所有被错误持久化的 ephemeral 临时消息
USE ultrasend;

DELETE FROM messages
WHERE data LIKE '%"type":"lan_file_offer"%'
   OR data LIKE '%"type":"lan_pull_probe"%'
   OR data LIKE '%"type":"lan_pull_probe_result"%'
   OR data LIKE '%"type":"lan_http_probe"%'
   OR data LIKE '%"type":"lan_http_probe_result"%'
   OR data LIKE '%"type":"webrtc_probe"%'
   OR data LIKE '%"type":"webrtc_probe_result"%'
   OR data LIKE '%"type":"webrtc_offer"%'
   OR data LIKE '%"type":"webrtc_answer"%'
   OR data LIKE '%"type":"webrtc_ice_candidate"%'
   OR data LIKE '%"type":"webrtc_transfer_cancel"%';
