#!/bin/sh
# 把 dsh-purge（破甲）+ local-purge（原生壳）装进当前 DSH profile。
# 在 DSH Go 的 App 内终端里跑，不需要 root。
#
#   sh install.sh                 # 下载最新 dsh-purge 并安装
#   sh install.sh --offline       # 只用已有的 $DSH_HOME/plugins-src/dsh-purge
#   sh install.sh --purge-src DIR # 用指定的 dsh-purge 目录
#   sh install.sh --profile web   # 指定 profile（默认 web）
set -eu

PROFILE=web
MODE=download
PURGE_SRC=
KIT_DIR=$(cd "$(dirname "$0")" && pwd)

while [ $# -gt 0 ]; do
  case "$1" in
    --offline) MODE=offline ;;
    --purge-src) MODE=local; PURGE_SRC=${2:?--purge-src 需要目录}; shift ;;
    --profile) PROFILE=${2:?--profile 需要名字}; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
  shift
done

DSH_HOME=${DSH_HOME:-$HOME/.dsh}
PROFILES="$DSH_HOME/profiles/$PROFILE"
NM="$PROFILES/node_modules"
STAGE="$DSH_HOME/plugins-src/dsh-purge"
GO_PLUGINS="$DSH_HOME/dsh-go/plugins"
STAMP=$(date +%Y%m%d-%H%M%S)

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v node >/dev/null 2>&1 || die "找不到 node，请在 DSH Go 的终端里运行"

[ -d "$PROFILES" ] || die "找不到 profile 目录: $PROFILES（先启动一次本机引擎）"

say "== 环境 =="
say "DSH_HOME = $DSH_HOME"
say "profile  = $PROFILE"
say "node     = $(node -v)"
say "dsh      = $(dsh --version 2>/dev/null || echo 未知)"

# ---------- 1. 备份 profile ----------
say ""
say "== 备份 =="
BAK="$DSH_HOME/profiles/$PROFILE.bak-$STAMP"
rm -rf "$BAK"
cp -a "$PROFILES" "$BAK"
say "backup = $BAK"

# ---------- 2. 准备 dsh-purge 源码 ----------
say ""
say "== dsh-purge 源码 =="
mkdir -p "$DSH_HOME/plugins-src"
case "$MODE" in
  local)
    [ -d "$PURGE_SRC" ] || die "目录不存在: $PURGE_SRC"
    rm -rf "$STAGE"
    cp -a "$PURGE_SRC" "$STAGE"
    say "从 $PURGE_SRC 复制"
    ;;
  offline)
    [ -f "$STAGE/package.json" ] || die "离线模式但 $STAGE 不存在"
    say "复用已有 $STAGE"
    ;;
  download)
    if [ -f "$STAGE/package.json" ]; then
      say "复用已有 $STAGE（要强制更新先删掉它）"
    else
      # 优先用仓库自带的 tarball：上游 GitHub 仓库可能已下线（404），
      # npm 上的 dsh-purge 也不是破甲本体，不能当来源。
      VENDOR=$(ls "$KIT_DIR"/vendor/dsh-purge-*.tgz 2>/dev/null | head -1 || true)
      TMP=$(mktemp -d)
      if [ -n "$VENDOR" ]; then
        say "使用仓库自带 $(basename "$VENDOR")"
        cp "$VENDOR" "$TMP/p.tgz"
      else
        URL=${PURGE_URL:-https://github.com/YuJunZhiXue/dsh-purge/archive/refs/heads/master.tar.gz}
        say "下载 $URL"
        if command -v curl >/dev/null 2>&1; then
          curl -fsSL "$URL" -o "$TMP/p.tgz" || die "下载失败：上游不可达。用 --offline 或 --purge-src 指定已有源码。"
        else
          wget -q "$URL" -O "$TMP/p.tgz" || die "下载失败：上游不可达。用 --offline 或 --purge-src 指定已有源码。"
        fi
      fi
      tar -xzf "$TMP/p.tgz" -C "$TMP"
      SRC=$(find "$TMP" -maxdepth 1 -type d -name 'dsh-purge*' | head -1)
      [ -n "$SRC" ] || die "压缩包结构异常"
      rm -rf "$STAGE"
      cp -a "$SRC" "$STAGE"
      rm -rf "$TMP"
    fi
    ;;
esac
[ -f "$STAGE/package.json" ] || die "$STAGE 缺少 package.json"
say "版本 = $(node -p "require('$STAGE/package.json').version" 2>/dev/null || echo 未知)"

# ---------- 3. 实体目录安装（关键：不用软链） ----------
say ""
say "== 安装到 node_modules（实体目录） =="
for name in dsh-purge local-purge; do
  rm -rf "$NM/$name"
done

cp -a "$STAGE" "$NM/dsh-purge"
say "dsh-purge   -> $NM/dsh-purge"

SRC_LOCAL="$KIT_DIR/plugins/local-purge"
[ -d "$SRC_LOCAL" ] || die "kit 里缺少 plugins/local-purge"
rm -rf "$GO_PLUGINS/local-purge"
mkdir -p "$GO_PLUGINS"
cp -a "$SRC_LOCAL" "$GO_PLUGINS/local-purge"
cp -a "$SRC_LOCAL" "$NM/local-purge"
say "local-purge -> $NM/local-purge（源在 $GO_PLUGINS/local-purge）"

# 兜底：万一源码里带了软链（pnpm/npm 的 link 农场），换成实体文件
find "$NM/dsh-purge" "$NM/local-purge" -type l 2>/dev/null | while read -r l; do
  t=$(readlink -f "$l" 2>/dev/null || true)
  if [ -n "$t" ] && [ -e "$t" ]; then
    rm -f "$l"; cp -a "$t" "$l"
  else
    rm -f "$l"
  fi
done

# ---------- 4. 注册到 profile ----------
say ""
say "== 注册到 package.json =="
node "$KIT_DIR/lib/profile.mjs" "$PROFILES/package.json" dsh-purge local-purge

# ---------- 5. 权限 ----------
if [ "$(id -u)" = "0" ]; then
  OWNER=$(stat -c '%u:%g' "$DSH_HOME" 2>/dev/null || echo "")
  if [ -n "$OWNER" ] && [ "$OWNER" != "0:0" ]; then
    chown -R "$OWNER" "$DSH_HOME/profiles/$PROFILE" "$DSH_HOME/plugins-src" "$DSH_HOME/dsh-go" 2>/dev/null || true
    say "已把属主改回 $OWNER"
  fi
fi

say ""
say "== 完成 =="
say "下一步：设置 › 本机引擎 › 重启引擎，然后回到对话。"
say "验证：sh $KIT_DIR/verify.sh"
say "回滚：rm -rf $PROFILES && cp -a $BAK $PROFILES"
