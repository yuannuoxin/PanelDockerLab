# S\-UI / 3X\-UI Docker 完整部署调试总结（避坑最终版）

## 一、本次部署核心方案（独创调试方式）

常规 Docker 直接启动会 **强制运行主程序，无法先改配置再启动**。

本次统一使用：**临时 tail 占位调试法**

原理：

- 覆盖容器入口为 `/bin/sh`

- 用 `tail -f /dev/null` 占位保持容器存活

- 容器启动后不运行面板程序，**先进容器改端口/配置**

- 配置改完，重建正式容器上线（数据持久不丢失）

解决两大致命坑：

1. CentOS SELinux 挂载权限报错**disk I/O error**

2. Docker seccomp 拦截 SQLite 数据库锁报错

---

## 二、S\-UI 完整部署流程（最终成功版）

### 1、调试模式容器（先改配置、不启动服务）

创建目录：

```Plain Text
mkdir -p ./db ./cert
```

调试启动命令（解决 SELinux \+ seccomp 双重报错）：

```Plain Text
docker rm -f s-ui

docker run -d \
--name s-ui \
--network host \
--security-opt seccomp=unconfined \
-v $PWD/db/:/app/db/:Z \
-v $PWD/cert/:/root/cert/:Z \
--entrypoint="/bin/sh" \
ghcr.io/admin8800/s-ui \
-c "tail -f /dev/null"
```

### 2、进入容器修改端口

```Plain Text
docker exec -it s-ui /bin/sh

# 查看原配置
./sui setting

# 修改端口（本次最终配置）
./sui setting -port 4095 -subPort 4096
```

✅ 最终 S\-UI 端口：

- 面板端口：**4095**

- 订阅端口：**4096**

- 访问地址：`http://IP:4095/app/`

### 3、调试完成 → 正式生产启动命令

删除调试容器，正式上线（配置持久保留）：

```Plain Text
docker rm -f s-ui

docker run -d \
--name s-ui \
--network host \
--restart=unless-stopped \
--security-opt seccomp=unconfined \
-v $PWD/db/:/app/db/:Z \
-v $PWD/cert/:/root/cert/:Z \
ghcr.io/admin8800/s-ui
```

---

## 三、3X\-UI 完整部署流程（特殊区别重点）

### 重点差异（最关键）

**3X\-UI 官方镜像强制要求：面板必须是容器 PID1 主进程**

无法像 S\-UI 一样后台手动启动，否则报错：

> Panel process is not running inside this container\.
> 
> 

### 1、3X\-UI 调试容器命令（改配置专用）

```Plain Text
docker rm -f 3x-ui
mkdir -p ./3x-ui/db ./3x-ui/cert

docker run -d \
--name 3x-ui \
--network host \
--security-opt seccomp=unconfined \
--cap-add=NET_ADMIN \
--cap-add=NET_RAW \
-v $PWD/3x-ui/db/:/etc/x-ui/:Z \
-v $PWD/3x-ui/cert/:/root/cert/:Z \
--entrypoint="/bin/sh" \
ghcr.io/mhsanaei/3x-ui:latest \
-c "tail -f /dev/null"
```

### 2、手动修改 3X\-UI 端口（无菜单报错方案）

直接修改配置文件（绕过进程检测）：

```Plain Text
docker exec -it 3x-ui /bin/sh
vi /etc/x-ui/config.json
```

修改 `panel_port` 为自定义端口，保存退出。

### 3、3X\-UI 最终正式上线命令

删除调试容器，用原生入口启动（配置不丢失）：

```Plain Text
docker rm -f 3x-ui

docker run -d \
--name 3x-ui \
--network host \
--restart=unless-stopped \
--security-opt seccomp=unconfined \
--cap-add=NET_ADMIN \
--cap-add=NET_RAW \
-v $PWD/3x-ui/db/:/etc/x-ui/:Z \
-v $PWD/3x-ui/cert/:/root/cert/:Z \
ghcr.io/mhsanaei/3x-ui:latest
```

### 4、3X\-UI 账号密码重置命令

```Plain Text
docker exec -it 3x-ui x-ui setting -username 自定义账号 -password 自定义密码
```

---

## 四、本次部署踩坑大全（核心避坑点）

#### 坑1：磁盘IO报错 operation not permitted

原因：CentOS SELinux \+ Docker seccomp 双重限制

解决：挂载加 **:Z** \+ 启动加 **\-\-security\-opt seccomp=unconfined**

#### 坑2：docker container update 不能改 entrypoint

结论：Docker 不支持运行中容器改入口，只能 **重建容器**（数据卷保留不丢配置）

#### 坑3：3X\-UI 不能后台手动启动

原因：镜像内置校验，必须 PID1 运行，只能改配置文件后重建容器

#### 坑4：sui 命令大小写问题

正确：`-subPort` 大写P，错误：`-subport`

---

## 五、最终运行参数汇总

### S\-UI

- 面板端口：4095

- 订阅端口：4096

- 网络模式：host

- 重启策略：unless\-stopped

### 3X\-UI

- 网络模式：host

- 必备权限：NET\_ADMIN / NET\_RAW / seccomp 放开

- 配置目录持久化：`./3x-ui/db -> /etc/x-ui`

---

## 六、日常维护常用命令

```Plain Text
# 查看日志
docker logs s-ui
docker logs 3x-ui

# 重启服务
docker restart s-ui
docker restart 3x-ui

# 进入容器
docker exec -it s-ui /bin/sh
docker exec -it 3x-ui /bin/sh
```

**文档结束：全套流程可永久复用，重装直接照搬**

> （注：部分内容可能由 AI 生成）
