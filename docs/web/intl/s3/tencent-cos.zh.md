# 腾讯云 COS 详细配置

本指南帮助你在腾讯云 **对象存储（COS）** 上创建桶、获取 API 密钥、配置 CORS，并在虾传设置页完成对接。

> 在腾讯云控制台搜索 **「对象存储」** 即可进入 COS；「对象存储」就是 COS 的产品名称。

## 适用场景

- 服务器或用户主要在中国大陆，希望使用国内节点中转。
- 已有腾讯云账号，希望数据留在 COS。

## 准备工作

1. 登录 [腾讯云控制台](https://console.cloud.tencent.com/)。
2. 搜索并进入 **对象存储**。
3. 开通 COS（按量计费或资源包均可）。

## 创建存储桶

1. 进入 **对象存储 → 存储桶列表 → 创建存储桶**。
2. 填写桶名称（全局唯一；创建后不可修改）。
3. 选择 **存储桶地域**（见下一节，地域会影响 Endpoint 与 Region）。
4. **访问权限** 选择 **私有读写**（安全性最好；文件通过密钥与预签名 URL 访问，无需公有读）。

![创建存储桶：访问权限选择私有读写](/docs/s3/tencent-cos/01-create-bucket-private.png)

## 选择地域与填写 Endpoint / Region

创建桶时需选择 **对象存储地域**。地域决定 S3 兼容 Endpoint 中的地域段，也与虾传设置里的 **Region** 字段一一对应。

例如选择 **广州** 时：

- Endpoint：`https://cos.ap-guangzhou.myqcloud.com`
- Region：`ap-guangzhou`

Endpoint 中 `cos.` 与 `.myqcloud.com` 之间的 **`ap-guangzhou`** 就是广州的地域代码；不同城市/园区代码不同，请以控制台所选地域为准。

![选择对象存储地域（示例：广州）](/docs/s3/tencent-cos/02-select-region.png)

| 控制台所选地域 | Endpoint 示例 | 虾传 Region |
| --- | --- | --- |
| 广州 | `https://cos.ap-guangzhou.myqcloud.com` | `ap-guangzhou` |
| 上海 | `https://cos.ap-shanghai.myqcloud.com` | `ap-shanghai` |
| 北京 | `https://cos.ap-beijing.myqcloud.com` | `ap-beijing` |

创建完成后，在桶详情或创建页 **请求域名** 处可核对上述 Endpoint；**Bucket** 填写完整桶名（通常含 APPID 后缀，如 `my-bucket-1314690352`）。

## 创建 API 密钥

虾传需要 COS 的 API 密钥才能签发上传/下载地址。推荐在 [API 密钥管理](https://console.cloud.tencent.com/cam/capi) 页面创建：

1. 打开 [https://console.cloud.tencent.com/cam/capi](https://console.cloud.tencent.com/cam/capi)。
2. 新建密钥，创建成功后得到 **SecretId** 与 **SecretKey**。
3. 密钥与虾传字段对应关系：
   - **SecretId** → 虾传 **Access Key ID**
   - **SecretKey** → 虾传 **Secret Access Key**

![API 密钥管理：SecretId 示例](/docs/s3/tencent-cos/03-cam-api-key.png)

> 建议使用子账号密钥，并只授权目标存储桶，不要使用主账号密钥。

## 配置 CORS

浏览器直传必须配置桶 CORS。打开目标桶 → **安全管理 → 跨域访问 CORS 设置 → 添加规则**，按下图填写即可：

![跨域访问 CORS 设置：Origin 与 Methods 示例](/docs/s3/tencent-cos/05-cors-rule.png)

- **来源 Origin**：`https://shrimpsend.com`（如有 `www` 域名另加一行）
- **操作 Methods**：勾选 **PUT、GET、POST、DELETE、HEAD**
- **Allow-Headers**：`*`
- **Expose-Headers**：`ETag`（可按控制台默认补充 `Content-Length`、`x-cos-request-id`）

## 填写虾传设置

在 **设置 → S3** 中按控制台信息填写，参考示例：

| 字段 | 说明 / 示例 |
| --- | --- |
| Endpoint | `https://cos.ap-guangzhou.myqcloud.com`（含 `https://`，地域段与所选地区一致） |
| Region | `ap-guangzhou`（与 Endpoint 中地域代码一致） |
| Bucket | 完整桶名，如 `xiachuan-relay-1314690352` |
| Path-style 访问 | **关闭**（COS 使用虚拟托管域名） |
| Access Key ID | CAM **SecretId** |
| Secret Access Key | CAM **SecretKey** |

![虾传 S3 设置最终配置示例（腾讯云 COS）](/docs/s3/tencent-cos/04-shrimpsend-settings.png)

## 测试连接

1. 点击 **测试连接**，应提示连接成功。
2. 在两台不同网络的设备间发送文件，确认走 S3 中转且无 CORS 报错。
3. 若失败，打开浏览器开发者工具 → Network，查看 PUT 请求是否被 CORS 拦截。

## 常见问题

**找不到 COS？**  
在控制台顶部搜索 **对象存储** 即可；产品名即 COS。

**Region 填什么？**  
填 Endpoint 里的地域代码（如 `ap-guangzhou`），与创建桶时所选 **存储桶地域** 一致，不是「广州」中文名。

**测试成功但上传失败？**  
多为 CORS Origin 未包含你实际打开 Web 的域名，或 Methods 缺少 `PUT`/`POST`。

**403 Access Denied？**  
检查密钥是否有目标桶的读写权限。
