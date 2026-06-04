# 开源许可说明（中文摘要）

> **法律效力以英文 [LICENSE](LICENSE)（GNU AGPL v3.0）为准。** 本文帮助中文读者快速理解使用边界。

**版权所有：** 北京明曼信息科技有限公司（Beijing Mingman Information Technology Co., Ltd.）  
**SPDX 标识：** `AGPL-3.0-or-later`

## 你可以做什么

- **查看、使用、修改** 本仓库全部源代码。
- **自托管**：在自己的服务器上部署后端、Web 与客户端，服务自己或所在组织。
- **Fork**：在遵守 AGPL 与 [TRADEMARK.md](TRADEMARK.md) 的前提下，使用**独立产品名与包名**发布社区版。
- **贡献代码**：见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [DCO.md](DCO.md)。

## 你需要遵守什么（AGPL 核心）

1. **保留许可与版权声明**，修改过的文件须注明改动。
2. **分发或提供软件**（含通过网络让用户使用你修改后的服务端/Web）时，须向对应用户提供**完整对应源码**（含你的改动），并同样以 AGPL 授权。
3. **衍生作品整体**须以 AGPL 发布，不能把核心后端闭源后再对外提供网络服务。

### 常见场景

| 场景 | 通常是否需要开源你的改动 |
| --- | --- |
| 个人/公司自托管，仅内部员工使用 | 若未对外提供网络服务，一般无额外开源义务；仍须保留原许可声明 |
| 修改后对外运营 `your-send.example.com` 给第三方用户 | **是** — 须按 AGPL 提供源码 |
| 仅使用官方 ShrimpSend / 虾传 云服务 | 受 [服务条款](docs/legal/) 约束，**不是** AGPL 被许可方关系 |
| 企业要把代码嵌入无法开源的专有产品 | 需 [商业授权](LICENSE-Commercial.md) |

## 官方服务 vs 社区 Fork

| | 官方 ShrimpSend / 虾传 | 社区自托管 Fork |
| --- | --- | --- |
| 品牌 | ShrimpSend / 虾传 | 必须使用**不同名称**（见 [TRADEMARK.md](TRADEMARK.md)） |
| 默认 API | 官方域名 | 须指向**自有**服务器 |
| 会员/计费 | 官方套餐 | 自行集成或省略 |
| 源码 | [GitHub 公开仓库](https://github.com/shrimpsend/shrimpsend) | 基于同一 AGPL 源码 Fork |

## 商业授权

若你的组织无法遵守 AGPL（例如：修改后对外提供 SaaS 但不愿公开源码，或需闭源集成），请联系版权方洽谈 **商业许可证**。详见 [LICENSE-Commercial.md](LICENSE-Commercial.md)。

- 邮箱：`cmlanche@qq.com`
- 主题：`ShrimpSend Enterprise License`

## 商标

**ShrimpSend**、**虾传** 及相关标识 **不属于** AGPL 授权范围。Fork 不得冒用官方品牌或暗示与官方有关联。详见 [TRADEMARK.md](TRADEMARK.md)。

## 第三方组件

本软件依赖大量第三方库与 SDK（含 Stripe、支付宝等）。它们各自受原许可证约束，汇总见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 免责声明

本摘要不构成法律意见。如有合规疑问，请咨询专业律师。
