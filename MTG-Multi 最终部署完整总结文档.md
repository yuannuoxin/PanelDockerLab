# MTG\-Multi 最终部署完整总结文档

## 一、核心镜像说明

本次使用镜像：**ghcr\.io/mhsanaei/mtg\-multi:latest**

⚠️ 重点区别（全网最大踩坑点）：

- **该镜像不支持 SECRET\_HOST 环境变量**，绝对不能写入启动命令，否则容器直接崩溃退出

- Fake\-TLS 伪装域名不再独立配置，**直接 Hex 编码嵌入 SECRET 密钥末尾**

- 和原版 MTG、Telegram 官方 Proxy 镜像参数完全不通用，不可混用配置

## 二、标准密钥格式（固定规则）

**完整 SECRET 结构 = ee \+ 32位随机十六进制密钥 \+ 伪装域名Hex编码**

本次最终采用伪装域名：**cloudflare\-ech\.com**（CF官方ECH公共域名，流量特征隐蔽）

域名固定Hex编码：`636c6f7564666c6172652d6563682e636f6d`

## 三、一键生成合规密钥命令（推荐）

无需手动拼接，零出错，自动生成适配当前镜像的完整密钥

```Plain Text
docker run --rm nineseconds/mtg:2 generate-secret --hex cloudflare-ech.com
```

## 四、最终正确启动命令（Host网络模式）

优势：宿主机网络直通、无需端口映射、延迟更低、稳定性更高

```Plain Text
# 删除旧容器
docker rm -f mtg

# 全新部署 mtg-multi（纯净无冗余参数）
docker run -d --name mtg \
--network host \
-e SECRET=此处粘贴生成的完整ee开头密钥 \
-e MTG_BIND_TO=0.0.0.0:19444 \
ghcr.io/mhsanaei/mtg-multi:latest
```

端口说明：固定监听 **19444**，需放行对应端口防火墙/安全组

## 五、端口与防火墙配置

### 1\. CentOS 防火墙放行

```Plain Text
firewall-cmd --add-port=19444/tcp --permanent
firewall-cmd --reload
```

### 2\. 云服务器安全组

手动放行：**TCP 19444** 入站规则（必须配置，否则外网无法连接）

## 六、TG代理链接标准模板（无IP）

两种格式完全等效，可直接替换IP和密钥使用

### 1\. 网页点击格式（通用）

```Plain Text
https://t.me/proxy?server=服务器IP&port=19444&secret=完整ee开头密钥
```

### 2\. 客户端协议格式

```Plain Text
tg://proxy?server=服务器IP&port=19444&secret=完整ee开头密钥
```

## 七、容器日常运维命令

```Plain Text
# 查看容器运行状态
docker ps

# 实时查看运行日志（排查连接问题核心命令）
docker logs -f mtg

# 退出日志查看
Ctrl + C

# 重启容器
docker restart mtg

# 删除容器重建
docker rm -f mtg
```

## 八、日志状态解读（关键）

### ✅ 正常日志（代理工作正常）

- `Stream has been started`：客户端成功建立连接

- `Stream has been finished`：连接正常关闭，转发无异常

### ✅ 可忽略报错（非故障）

`cannot read client hello: unexpected record type 0xXX`

成因：公网端口被扫描器、爬虫、HTTP探针探测，非标准TLS流量被拦截，属于正常防护行为，无需处理。

## 九、致命踩坑汇总（必看）

1. **禁止使用 openssl s\_client 测试服务**：该镜像为专属Fake\-TLS协议，普通TLS握手会直接失败，无法作为判断服务状态的依据

2. **禁止添加 SECRET\_HOST 环境变量**：添加直接启动崩溃

3. **密钥必须完整一致**：服务端SECRET、客户端链接密钥必须完全相同，缺一不可、不可截断

4. **端口统一**：监听端口、防火墙端口、链接端口必须统一（本次固定19444）

5. **系统时间必须准确**：服务器/客户端时间偏差过大，会导致TLS握手失败、连接超时

## 十、服务判定标准

- 容器状态为 Up 正常运行，无自动退出

- 客户端连接时，日志出现 Stream 启停记录

- 无密钥报错、配置报错，仅存在常规端口扫描日志

**⚠️ 合规提示：本文档仅用于技术原理学习，搭建相关代理服务请遵守当地法律法规。**



> （注：部分内容可能由 AI 生成）
