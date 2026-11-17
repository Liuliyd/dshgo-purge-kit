#!/bin/sh
# 备用安装：PC 上通过 adb + root，把 kit 装进 DSH Go 的 proot rootfs。
# 适用于设备已 root（KernelSU / Magisk）且你不想在 App 里敲命令的情况。
#
#   sh install-adb.sh                 # 自动找 rootfs 和 uid
#   sh install-adb.sh --pkg io.github.ccch1mneyyy.dsh_app
set -eu

PKG=${PKG:-io.github.ccch1mneyyy.dsh_app}
KIT_DIR=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

while [ $# -gt 0 ]; do
  case "$1" in
    --pkg) PKG=${2:?}; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v adb >/dev/null 2>&1 || die "找不到 adb"
adb get-state >/dev/null 2>&1 || die "没有设备，先 adb connect / 插线"

UID_APP=$(adb shell "stat -c %u /data/user/0/$PKG" 2>/dev/null | tr -d '\r')
[ -n "$UID_APP" ] || die "拿不到 $PKG 的 uid，设备可能没 root"

# rootfs 从 proot 启动参数里读，别写死
ROOTFS=$(adb shell "su -c 'ps -A -o ARGS 2>/dev/null | grep -o \"rootfs=[^ ]*\" | head -1'" 2>/dev/null | tr -d '\r' | cut -d= -f2-)
[ -n "$ROOTFS" ] || ROOTFS="/data/user/0/$PKG/files/runtime/rootfs"
say "rootfs = $ROOTFS"
say "uid    = $UID_APP"

# ---------- 推 kit ----------
say ""
say "== 推送 kit =="
adb shell "rm -rf /data/local/tmp/dshgo-purge-kit"
adb push "$KIT_DIR" /data/local/tmp/dshgo-purge-kit >/dev/null
adb shell "chmod -R 755 /data/local/tmp/dshgo-purge-kit"

# ---------- rootfs 内执行安装 ----------
say ""
say "== 在 rootfs 内安装（chroot） =="
cat > /tmp/dshgo-install-inner.sh <<INNER
#!/bin/sh
set -eu
R=$ROOTFS
chroot \$R /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
  HOME=/root USER=root LOGNAME=root SHELL=/bin/bash LANG=C.UTF-8 TMPDIR=/tmp TERM=xterm \\
  DSH_HOME=/root/.dsh /bin/bash -lc '
set -eu
KIT=/data/local/tmp/dshgo-purge-kit
# /data 在 rootfs 内不可见，先把 kit 拷进 rootfs 再跑
DEST=/root/.dsh/.kit-\$(date +%s)
mkdir -p "\$DEST"
cp -a \$KIT/. "\$DEST/"
sh "\$DEST/install.sh" --offline --purge-src "\$DEST/../plugins-src/dsh-purge" 2>/dev/null || sh "\$DEST/install.sh"
'
INNER
adb push /tmp/dshgo-install-inner.sh /data/local/tmp/dshgo-install-inner.sh >/dev/null

# kit 与 dsh-purge 源码先进 rootfs，绕开 /data 不可见
adb shell "su -c 'cp -a /data/local/tmp/dshgo-purge-kit $ROOTFS/root/.kit && chown -R root:root $ROOTFS/root/.kit'"
adb shell "su -c 'sh /data/local/tmp/dshgo-install-inner.sh'"

# ---------- 属主 + 重启 ----------
say ""
say "== 修属主并重启 App =="
adb shell "su -c 'chown -R $UID_APP:$UID_APP $ROOTFS/root/.dsh'"
adb shell "su -c 'am force-stop $PKG'"
sleep 2
adb shell "su -c 'am start -n $PKG/.LauncherMist'" >/dev/null 2>&1 || adb shell "monkey -p $PKG 1" >/dev/null 2>&1 || true

say ""
say "等 45 秒后验证："
say "  adb shell \"su -c 'cat $ROOTFS/root/.dsh/dsh-go/local-purge.loaded.json'\""
say "  adb shell \"su -c 'tail -5 $ROOTFS/../logs/dsh.log'\""
