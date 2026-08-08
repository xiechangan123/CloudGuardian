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

## 在 Alpine Linux 上安装与运行（本仓库专用）

本仓库已针对 **Alpine Linux + OpenRC** 全面优化，使用 POSIX `sh` 编写。

### 1. 安装依赖

```sh
sudo apk update
sudo apk add jq util-linux coreutils
```

- `jq`：必须
- `util-linux`：提供 `mktemp` 等工具
- `coreutils`：提供更好的 `date` 支持（推荐）

### 2. 启用系统自带的 crond（BusyBox）

```sh
sudo rc-update add crond default
sudo rc-service crond start
```

### 3. 克隆并配置

```sh
cd ~
git clone https://github.com/xiechangan123/CloudGuardian.git
cd CloudGuardian
cp .env.example .env
```

编辑 `.env` 文件，重点修改：

- `NIC`：网卡名称（通常是 `eth0` 或 `ens4`）
- `TX_BYTES_LIMIT`：每日流量上限（单位：字节，默认约 6G）

### 4. 添加定时任务（每分钟执行一次）

Alpine 使用 BusyBox crond，推荐直接编辑 `/etc/crontabs/root`：

```sh
echo "* * * * * cd /root/CloudGuardian && ./run.sh" >> /etc/crontabs/root
```

或根据实际路径修改后执行：

```sh
crontab -e
```

添加一行：

```
* * * * * cd /你的路径/CloudGuardian && ./run.sh
```

### 5. 确保服务已安装

脚本通过 OpenRC 管理以下服务（对应 `/etc/init.d/` 下的名字）：

- nginx
- v2ray
- x-ui
- sing-box

请提前安装好对应服务，并确保存在 `/etc/init.d/对应服务名`。

---

**注意事项：**

1. 脚本必须以 **root** 身份运行。
2. 在容器中运行时，可能无法直接读取宿主机的 `/sys/class/net`，需要挂载相应路径或使用模拟数据。
3. 本仓库为 Alpine-only 优化版本，已不再依赖 `systemctl`。

---

#### 如果这个工具帮到了您，是否可请我喝杯咖啡？金额随意，谢谢！

| ![pay_tencent](./.res/pay_tencent.png) | ![pay_ali](./.res/pay_ali.png) |
| -------------------------------------- | ------------------------------ |

---

**如果你觉得这个工具有用，麻烦请 Star，如果您有意见或者建议，欢迎提 Issue！**

您的支持是我坚持的动力，感谢！
