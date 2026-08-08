## 在 Alpine Linux 上安装与运行（本仓库专用）

本仓库针对 **Alpine Linux 3.24 + BusyBox + OpenRC** 原生重写，逻辑参照 [yongxin-ms/CloudGuardian](https://github.com/yongxin-ms/CloudGuardian)，**仅依赖 Alpine 官方软件包，不使用 Docker / util-linux / coreutils**。

### 1. 安装依赖

```sh
apk -U upgrade
apk add jq
```

仅需 `jq`。`date`、`mktemp`、`mkdir`、`crond` 等全部使用 Alpine 自带 BusyBox。

### 2. 克隆并配置

```sh
cd ~
git clone https://github.com/xiechangan123/CloudGuardian.git
cd CloudGuardian
cp .env.example .env
```

编辑 `.env`（系统自带 `vi`，推荐）：

```sh
vi .env
```

常用操作：

| 按键 | 作用 |
|------|------|
| `i` | 进入编辑模式 |
| 改完后按 `Esc` | 退出编辑模式 |
| `:wq` 回车 | 保存并退出 |
| `:q!` 回车 | 不保存退出 |

配置项说明：

- `NIC`：网卡名称（谷歌云默认是 `eth0`）
- `TX_BYTES_LIMIT`：每日流量上限（单位：字节，默认约 6G；不能写 `100M` 这种带单位的，需写成纯数字，例如 100MB = `104857600`）

### 3. 以 root 运行脚本（直接运行用于调试/一次性执行） 

```sh
chmod +x run.sh && ./run.sh
```

### 4. 添加定时任务（每分钟执行一次）

Alpine BusyBox crond 使用 `/etc/crontabs/root`：

```sh
echo "* * * * * cd CloudGuardian && ./run.sh" >> /etc/crontabs/root
```

或：

```sh
crontab -e
```

添加：

```
* * * * * cd /你的路径/CloudGuardian && ./run.sh
```

### 5. 重启系统自带的 crond（BusyBox）

```sh
rc-service crond restart
```

### 6. 确保服务已安装

脚本通过 OpenRC 管理以下服务（对应 `/etc/init.d/`）：

- nginx
- v2ray
- x-ui
- sing-box

请提前安装好对应服务。

### 7. 查看流量使用情况

#### 方式一：查看脚本统计（data.json）

```sh
cd CloudGuardian && cat data.json
```

字段说明：
- `last_update`：上次更新的时间戳
- `current`：网卡累计已发送字节
- `addup`：今日累计出站流量（字节），超过 `TX_BYTES_LIMIT` 会停止服务

#### 方式二：安装 vnstat（可选，更直观）

```sh
apk add vnstat
rc-update add vnstatd default
rc-service vnstatd start
```

常用命令：

```sh
vnstat                 # 总览
vnstat -i eth0         # 指定网卡（谷歌云默认 eth0）
vnstat -d -i eth0      # 按天
vnstat -m -i eth0      # 按月
vnstat -l -i eth0      # 实时
```

说明：`vnstat` 仅用于查看，不参与脚本限速逻辑；需运行一段时间后才有历史数据。

---

**注意事项：**


1. 脚本必须以 **root** 身份运行。
2. 本仓库为 Alpine-only 原生版本，使用 BusyBox `date` / `mktemp`，用 `mkdir` 实现互斥锁（替代原版 `flock`），用 `rc-service` 替代 `systemctl`。
3. 在容器中运行时可能无法读取宿主机 `/sys/class/net`，需挂载相应路径。

---

## 告别费用焦虑，畅享永久免费的 Google Cloud VPS！

还在为 Google Cloud 虚拟机一不小心产生的高昂的流量费用而烦恼吗？现在，这一切都将成为过去！

**Cloud-Guardian 助您轻松掌控 Google Cloud 虚拟机流量，将每月 200G 免费流量用到极致，彻底告别额外费用，放心使用，永久免费！**

**核心优势：**

- **精准流量控制：** 实时监控虚拟机流量使用情况，精确控制出站流量，确保始终在 200G 免费额度内，避免产生任何额外费用。
- **简单易用：** 无需复杂配置，只需简单几步即可完成设置，即使是新手用户也能轻松上手。
- **安全可靠：** 不安装额外软件，确保数据安全和隐私，让您使用无忧。

**适用场景：**

- **个人用户：** 搭建个人网站、博客、云盘等，享受高速稳定的网络环境，无需担心流量费用。
- **开发者：** 部署测试环境、开发应用，享受灵活的云计算资源，降低开发成本。

**您将获得：**

- **真正的永久免费：** 可以无需支付任何费用，即可享受 Google Cloud 的高性能 VPS。
- **更低的成本：** 告别高昂的流量费用，大幅降低云服务使用成本。
- **更自由的体验：** 无需担心流量超标，尽情享受云计算带来的便利。

**立即行动，开启您的永久免费 Google Cloud VPS 之旅！**

**Cloud-Guardian - 让云计算更简单，更经济！**

---

#### 效果展示：

以每天 0.25G 流量上限为例（这个数值可修改，**GCP 实际每天可使用约 6G 上传流量，只要每月不超过 200G 即可**）展示一下效果：

##### 达到额度之前：

![status_enabled](./.res/status_enabled.png)

##### 达到额度之后：

![status_disabled](./.res/status_disabled.png)

---

#### 环境准备：

##### 请自备：

- Google 账户
- 信用卡，用于将 Google 账户升级到付费账户
- GCP VPS，每月 200GB 免费标准层，VPS 创建方法请自己搜索，这里不提供。

##### 谷歌云永久免费服务器限制要求：

- 地区限制：在美国的以下区域俄勒冈、爱荷华、南卡罗来纳
- 磁盘限制：30 GB 标准永久性磁盘
- 网络服务层级：标准（每个区域每月可免费传输 200GB 数据）

---



**如果你觉得这个工具有用，麻烦请 Star，如果您有意见或者建议，欢迎提 Issue！**

您的支持是我坚持的动力，感谢！
