# dshgo-purge-kit

把桌面版 **dsh-purge（破甲）** 装进手机 **DSH Go** 的引擎，并补一个原生壳插件，让「破甲」出现在 App 原生界面（状态条 / 胶囊 / 面板 / 长按菜单）里。

> 实测环境：DSH Go `io.github.ccch1mneyyy.dsh_app` 1.1.0（引擎 `dsh 0.2.2-rc.1`，Android arm64，proot Ubuntu rootfs），dsh-purge 1.1.71。

---

## 这个仓库解决的两个坑

### 坑 1：`dsh plugin add` 装完引擎起不来

`dsh plugin add` 转发给 pnpm，pnpm 在 profile 的 `node_modules` 里生成的是**指向 `/root/.l2s/.l2s.<hash>` 的绝对路径软链**。DSH Go 的引擎跑在 proot 里，rootfs 内看不到 Android 的 `/data/user/0/...`，软链全部变成死链：

```
Error: EACCES: permission denied, realpath '/root/.dsh/profiles/web/node_modules/dsh-purge'
dsh: skipping profile bundle "dsh-purge": cannot resolve profile bundle ...
[mono=...] [dsh-app] DSH exited with code 1
```

表现就是：**App 打不开、聊天没了、插件列表空**。

所以本仓库的安装器**不走 pnpm**，而是把插件作为**实体目录**放进 `profiles/web/node_modules/`。实测启动干净、零 skip。

### 坑 2：npm 上叫 `dsh-purge` 的包不是破甲

`@manbaout-08/dsh-purge`（CTTWang）是「永久删除会话/工作区」的小工具，只是同名。真正的破甲是 `YuJunZhiXue/dsh-purge`（本仓库安装的那个）。

---

## 装什么

| 组件 | 作用 | 来源 |
|---|---|---|
| `dsh-purge` | 破甲本体：提示词注入、`/purge` `/rules` `/skills` `/rewind`、`purge_apply` 等工具 | 本仓库 `vendor/dsh-purge-1.1.71.tgz` |
| `local-purge` | 原生壳：把破甲状态搬到 App 原生 UI | 本仓库 `plugins/local-purge` |

> **为什么自带 tarball**：上游 `YuJunZhiXue/dsh-purge` 和 `HunYiSage/dsh-purge` 现在都返回 404，npm 上的 `dsh-purge` 只有 `0.0.0-stage`（不是破甲本体）。所以 `install.sh` 按 `vendor/` → [Release 附件](https://github.com/Liuliyd/dshgo-purge-kit/releases/tag/v1.1.71) → 上游 URL 的顺序取，可用 `PURGE_URL` 覆盖。

## Releases

| tag | 内容 |
|---|---|
| [v1.1.71](https://github.com/Liuliyd/dshgo-purge-kit/releases/tag/v1.1.71) | 首个可用版本；附件 `dsh-purge-1.1.71.tgz`（1.46 MB，SHA256 `03FCF9C9…EF437`） |

只想要破甲本体、不装原生壳的话，直接下附件：

```sh
curl -fL -o dsh-purge-1.1.71.tgz https://github.com/Liuliyd/dshgo-purge-kit/releases/download/v1.1.71/dsh-purge-1.1.71.tgz
sh install.sh --purge-src <解压后的目录>
```


装完在手机上能看到：

- 输入框上方 **状态条**：`破甲 apply:1.1.71 · 注入 24.5K`
- 输入框上方 **胶囊**「破甲状态」→ 打开「破甲控制台」
- 加号面板 → 「破甲详情」
- 长按 AI 回复 → 「净化这段回复」（只插入输入框，不自动发送）

写入类操作仍在网页版：`/purge status|apply|revert|uninstall`、`/rules`、`/skills`、`/rewind`，以及 `purge_apply` / `purge_revert` / `purge_status`。

---

## 安装（推荐：App 内终端，不需要 root）

在 DSH Go 里打开 **终端**（`全部功能 › 终端`，或对话里让 agent 执行）：

```sh
cd /tmp
node -e 'const fs=require("fs");fetch("https://codeload.github.com/Liuliyd/dshgo-purge-kit/tar.gz/refs/heads/main",{signal:AbortSignal.timeout(90000)}).then(async r=>{if(!r.ok)throw new Error("HTTP "+r.status);fs.writeFileSync("/tmp/kit.tgz",Buffer.from(await r.arrayBuffer()));console.log("ok")}).catch(e=>{console.error(e.message);process.exit(1)})'
tar -xzf kit.tgz
cd dshgo-purge-kit-main
sh install.sh
```

装完在 **设置 › 本机引擎 › 重启引擎**，回到对话即可。

> **为什么不用 `curl ... | sh`**：DSH Go 的 rootfs 里**没有 curl，也没有 wget**（实测 `command -v curl` 空）。只有 `node`、`python3`、`pnpm`。所以上面用 `node -e` 拉包。如果你的环境有 curl，也可以用 `bootstrap.sh`：
>
> ```sh
> sh bootstrap.sh                    # 依次试 codeload / archive，自动解包并安装
> sh bootstrap.sh --mirror https://ghfast.top
> ```
>
> `bootstrap.sh` 内部也是用 node 下载，不依赖 curl/wget。

装完在 **设置 › 本机引擎 › 重启引擎**，回到对话即可。

### 安装器做了什么

1. 读 `DSH_HOME`（默认 `~/.dsh`）、profile（默认 `web`）。
2. 下载 dsh-purge 源码到 `$DSH_HOME/plugins-src/dsh-purge`（已有则复用，`--offline` 强制复用）。
3. 复制 `local-purge` 到 `$DSH_HOME/dsh-go/plugins/local-purge`。
4. **实体目录**复制到 `profiles/web/node_modules/dsh-purge` 和 `.../local-purge`（先 `rm -rf`，绝不留软链）。
5. 改 `profiles/web/package.json`：写 `dependencies`，把两个名字追加进 `dsh.profile.bundles`。
6. 备份原 profile 到 `profiles/web.bak-<时间戳>`。
7. 打印下一步（重启引擎）。

全程幂等，重复跑不会叠加。

### 不需要 root 的原因

DSH Go 的引擎以 App 自己的 uid 跑在 proot 里，`$DSH_HOME=/root/.dsh` 在 rootfs 内就是这个 uid 的家目录，App 内终端天然可写。**不要**用 `adb shell` 直接写 `/data/user/0/...`（那是 root 才行的路径）。

---

## 安装（备用：PC + adb + root）

设备已 root（KernelSU / Magisk）时：

```sh
sh install-adb.sh
```

它把 kit 推到 `/sdcard/Download`，再用 `su -c chroot <rootfs>` 执行同一套逻辑，最后 `chown -R` 回 App 的 uid 并重启 App。rootfs 路径从 `libproot.so` 的启动参数里自动解析，不写死。

---

## 验证

```sh
sh verify.sh
```

判定标准：

| 检查 | 期望 |
|---|---|
| 引擎进程 | 有 `bin.js web` |
| `127.0.0.1:3080` | LISTEN |
| 日志 `skipping profile bundle` | 0 条 |
| `$DSH_HOME/dsh-purge/installed-rev` | `apply:<版本>` |
| `$DSH_HOME/prompt-inject.md` | 非空（约 25 KB） |
| `$DSH_HOME/dsh-go/local-purge.loaded.json` | 存在（引擎确实挂上了原生半侧） |

最后一条最关键：这个文件是 `local-purge` 在 `apply()` 里自己写的，能证明原生壳真的被引擎加载，而不是只躺在磁盘上。

---

## 卸载 / 回滚

```sh
sh uninstall.sh          # 移除两个插件，保留备份
```

手工回滚到安装前：

```sh
cd "$DSH_HOME/profiles"
ls -d web.bak-*                       # 挑一个
rm -rf web && cp -a web.bak-20260101-000000 web
```

然后重启引擎。

---

## 已知限制

- **不要**在 App 的「设置 › 插件」里对这两个插件点**更新 / 重装**。那会重新走 pnpm，生成死链，立刻回到坑 1。升级请重跑本仓库的 `install.sh`。
- 破甲的写入类动作（apply/revert）会改 `$DSH_HOME/prompt-inject.md` 和 override 文件，原生壳只读状态，不做写入。
- `dsh-purge` 的 `dshTarget` 是 `0.2.0-rc.2`，引擎 `0.2.2-rc.1` 实测可加载；跨大版本（0.3.x）需要重新验证 patch 的 loader id。
- 安全模式下不加载插件，此时看不到状态条。

---

## 目录

```
install.sh               App 内终端安装（无 root）
install-adb.sh           PC + adb + root 安装
uninstall.sh             卸载
verify.sh                体检
lib/profile.mjs          package.json 读写助手
plugins/local-purge/     原生壳插件源码
docs/troubleshooting.md  排错
```

## License

本仓库脚本与 `local-purge` 为 MIT。`dsh-purge` 由 [YuJunZhiXue/dsh-purge](https://github.com/YuJunZhiXue/dsh-purge) 提供，Apache-2.0，安装时下载，不随本仓库分发。
