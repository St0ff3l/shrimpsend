# 文本编码测试样例

用于验证 App 文本预览的自动编码检测功能。

## 文件说明

| 文件 | 编码 | 预期显示 |
|------|------|----------|
| `01_utf8_chinese.csv` | UTF-8（无 BOM） | 中文表头与数据正常 |
| `02_utf8_bom.txt` | UTF-8（带 BOM） | 「中文内容 UTF-8 BOM」等 |
| `03_gbk_campus_card.csv` | **GBK** | 校园卡流水 CSV，中文全部正常（修复前会乱码） |
| `04_ascii_plain.txt` | ASCII / UTF-8 | 英文与数字正常 |
| `05_utf16le_chinese.txt` | UTF-16 LE（带 BOM） | 「UTF-16 LE 中文测试」等 |
| `06_gbk_readme.txt` | **GBK** | GBK 说明段落，中文正常 |

## 如何测试

1. 将本目录下的文件发送到手机（AirDrop、聊天传输、文件管理导入等）
2. 在 App 中点击文件，以文本方式打开
3. 重点验证 **`03_gbk_campus_card.csv`** 和 **`06_gbk_readme.txt`** 是否显示正常中文
4. 可选：点击「复制全部」，粘贴到备忘录确认内容与屏幕一致

## 重新生成

```bash
cd app && dart run tool/generate_text_encoding_samples.dart
```
