# Docker Host模式网络与端口联调测试总结文档

## 一、核心概念：Host模式 vs Bridge模式（最关键区别）

### 1\. Bridge 模式（默认模式）

- **网络隔离**：容器拥有独立虚拟网卡、独立IP

- **端口规则**：支持 `-p 宿主机端口:容器端口` 任意映射

- **特点**：端口可随意改、冲突少、适合绝大多数业务

- **缺点**：二层NAT转发，拿不到用户真实源IP

### 2\. Host 模式（主机网络模式）

- **网络合并**：容器直接复用宿主机网卡、IP、网络栈，**无网络隔离**

- **端口铁律**：**不支持 \-p 端口映射**，\-p 参数会直接失效、被忽略

- **端口来源**：端口由「容器内应用监听端口」决定，应用监听哪个端口，宿主机就占用哪个端口

- **优点**：无NAT、性能高、能获取客户端真实IP，适合联调、网关、抓包测试

## 二、Host模式常见误区（重点避坑）

- **误区1**：以为可以用 `-p` 改端口 → 错误，Host模式完全无效

- **误区2**：容器监听 `127.0.0.1` → 外部无法访问，必须监听 `0.0.0.0`

- **误区3**：Windows/Mac Docker Desktop用Host模式 → 桌面版Host模式不完整、不推荐用于联调，仅Linux原生Docker支持完整Host网络

- **误区4**：多容器共用同一端口 → Host模式端口全局独占，同端口只能跑一个服务

## 三、Host模式自定义端口原理

想要任意指定端口（如 8080/9090/10086）：

✅ **正确方式**：修改容器内应用的监听端口

❌ **错误方式**：docker run \-p 映射端口

简单理解：**Host模式没有端口映射层，端口是服务自己“占”的**。

## 四、生产/联调专用测试服务（可直接复用）

场景：浏览器/接口联调，**自动返回请求路径、请求方式、全部请求头、请求Body**，JSON格式，标准接口调试工具。

### 1\. Host模式启动（自定义端口9090，可随意改）

```bash
docker run --rm -d --network host --name test-headers alpine sh -c "
apk add python3;
python3 -c '
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def _read_body(self):
        cl = int(self.headers.get(\"Content-Length\",0))
        return self.rfile.read(cl).decode(\"utf-8\") if cl>0 else \"\"

    def do_GET(self):
        self.do_common()
    def do_POST(self):
        self.do_common()

    def do_common(self):
        body = self._read_body()
        headers = dict(self.headers)
        resp = {
            \"path\": self.path,
            \"method\": self.command,
            \"headers\": headers,
            \"body\": body
        }
        self.send_response(200)
        self.send_header(\"Content-Type\",\"application/json;charset=utf-8\")
        self.end_headers()
        self.wfile.write(json.dumps(resp, ensure_ascii=False, indent=2).encode(\"utf-8\"))

# 修改此处端口即可自定义端口 0.0.0.0:xxxx
HTTPServer((\"0.0.0.0\",9090), Handler).serve_forever()
'
"
```

### 2\. 功能支持

- 支持 GET / POST 全部请求

- 返回完整浏览器/客户端请求头

- 返回请求路径、URL参数

- 返回POST提交的Body数据

- 标准JSON格式，前端、后端、网关联调通用

### 3\. 访问测试

浏览器 / curl / Postman 直接访问：

```bash
curl http://127.0.0.1:9090/test?name=test
```

### 4\. 停止测试容器

```bash
docker stop test-headers
```

## 五、端口排查命令（Host模式专用）

查看宿主机端口是否被Docker占用：

```bash
ss -tpln | grep 9090
netstat -tpln | grep 9090
```

## 六、适用场景总结

### 优先用 Host模式

- 需要获取客户端真实IP（网关、登录、风控联调）

- 需要抓包调试、网络直通测试

- 高性能、无NAT转发场景

### 优先用 Bridge模式

- 需要随意自定义映射端口

- 多容器端口复用、隔离部署

- 日常开发、业务部署（90%场景）

## 七、极简一句话终极总结

**Bridge模式：端口我随便映射；Host模式：服务监听啥端口，宿主机就用啥端口，无映射、无隔离、真实网络环境，最适合网络联调测试。**

> （注：部分内容可能由 AI 生成）
