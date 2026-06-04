# App Store 审核 Demo 账号（ShrimpSend intl）

审核用 Demo 账号凭证**不存放在公开仓库**。提审前请向项目维护者索取，或查阅私有 `shrimpsend-ops` 仓中的 runbook。

## 提审前运维 Checklist

1. **确认用户存在**于生产数据库（`api.shrimpsend.com` / `prod-overseas`）
2. **设备名额**：免费档默认 3 台；审核 iPad 登录前清理多余设备或授予 Plus/Pro
3. **会员状态**（可选）：便于审核员测试 Membership 页
4. **实测路径**：release intl 包 + iPad → 登录 → 设置 → 会员中心
5. **App Store Connect**：Review Information 填写维护者提供的 Demo 凭证

## 常见问题

| 现象 | 可能原因 |
| --- | --- |
| 「邮箱或密码错误」 | 用户不存在或密码 hash 不匹配 |
| 登录失败无明确提示 | 设备名额已满 |
| 已登录但点会员跳登录 | refreshToken 缺失；需客户端 1.3.3+ |
| IAP 无法购买 | Sandbox Tester 未配置；RC / ASC Product ID 不一致 |
