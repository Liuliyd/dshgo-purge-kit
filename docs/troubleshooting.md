# 排错

## 现象：装完后 App 打不开 / 聊天没了 / 插件列表空

这是**软链死链**导致的引擎启动失败。DSH Go 的引擎跑在 proot 里，pnpm 生成的 `node_modules/<pkg>` 是指向 `/root/.l2s/.l2s.<hash>` 的绝对路径软链，rootfs 内解析不到 Android 的 `/data/user/0/...`。

日志特征（`<rootfs>/../logs/dsh.log` 或 `$DSH_HOME` 同级 `runtime/logs/dsh.log`）：

```
dsh: skipping profile bundle "dsh-purge": cannot resolve profile bundle ...
Error: EACCES: permission denied, realpath '.../node_modules/dsh-purge'
[mono=...] [dsh-app] DSH exited with code 1
```

修：

```sh
ls -la "$DSH_HOME/profiles/web/node_modules/"     # 看到 lrwxrwxrwx 就是它
sh install.sh                                      # 安装器会用实体目录覆盖
```

安装器装完再确认一次：

```sh
find "$DSH_HOME/profiles/web/node_modules/dsh-purge" -type l
```

应无输出。

## 现象：装完能进 App，但看不到「破甲」

1. 先跑 `sh verify.sh`。`原生壳加载标记` 那项 FAIL 说明 `local-purge` 没被引擎加载。
2. 确认 `profiles/web/package.json` 的 `dsh.profile.bundles` 里有 `local-purge`。
3. 确认 `profiles/web/node_modules/local-purge` 是实体目录。
4. **重启引擎**（设置 › 本机引擎 › 重启引擎），再把 App 从后台划掉重开。只重开 App 不会重载 `lib/`。

## 现象：状态条显示「破甲未生效」

`$DSH_HOME/dsh-purge/installed-rev` 和 `$DSH_HOME/prompt-inject.md` 都没有。说明 `dsh-purge` 没真正跑起来（虽然目录在）。

在对话里执行 `/purge status`，或让 agent 调 `purge_status`，看它报什么。

## 现象：升级后在插件页点了「更新」，又崩了

插件页的更新走 pnpm，重新生成软链。恢复：

```sh
rm -rf "$DSH_HOME/profiles/web/node_modules/dsh-purge"
cp -a "$DSH_HOME/plugins-src/dsh-purge" "$DSH_HOME/profiles/web/node_modules/dsh-purge"
```

然后重启引擎。以后升级一律重跑 `install.sh`，不要点插件页的更新。

## 现象：`install.sh` 下载 dsh-purge 失败

网络到不了 GitHub 时：

```sh
# 用本机已有的源码（桌面版装过就有）
sh install.sh --offline
# 或指定一份
sh install.sh --purge-src /path/to/dsh-purge
```

桌面版默认在 `~/.dsh/profiles/desktop/node_modules/dsh-purge`。

## 现象：`chown` 之后还是读不了

引擎以 App 的 uid 跑。整个 `$DSH_HOME` 必须归那个 uid：

```sh
ls -ld "$DSH_HOME"                                  # 看属主数字
chown -R <uid>:<gid> "$DSH_HOME"                    # 需要 root
```

用 root 的 chroot 装过之后**一定要**跑这一步，否则 `~/.dsh` 里会留下 root 属主的文件，引擎写入时失败。

## 现象：安全模式

连续两次启动失败后 App 会自动进安全模式，此时不加载任何插件，看不到状态条是正常的。修好后再「恢复正常模式」。

## 拿日志

```sh
# App 内终端
tail -80 /data/user/0/io.github.ccch1mneyyy.dsh_app/files/runtime/logs/dsh.log 2>/dev/null
# rootfs 内
tail -80 /tmp/../$(ls -d /*/ 2>/dev/null | head -1) 2>/dev/null
```

PC + adb（需 root）：

```sh
adb shell "su -c 'tail -80 /data/user/0/io.github.ccch1mneyyy.dsh_app/files/runtime/logs/dsh.log'"
adb shell "su -c 'cat /data/user/0/io.github.ccch1mneyyy.dsh_app/files/runtime/logs/failure-latest.log'"
```

`failure-latest.log` 就是上一次启动失败的原因，最直接。
