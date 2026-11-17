#!/system/bin/sh
# dshgo-purge-kit 一键安装（DSH Go 引擎内运行，不需要 curl / wget / root）
#   sh bootstrap.sh
#   sh bootstrap.sh --mirror https://ghfast.top
set -eu

REPO=${REPO:-Liuliyd/dshgo-purge-kit}
BRANCH=${BRANCH:-main}
MIRROR=${MIRROR:-}

while [ $# -gt 0 ]; do
  case "$1" in
    --mirror) MIRROR=${2:?}; shift ;;
    --repo) REPO=${2:?}; shift ;;
    --branch) BRANCH=${2:?}; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v node >/dev/null 2>&1 || { echo "ERROR: 找不到 node，请在 DSH Go 的终端里运行" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

URLS="
https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH
https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz
"
if [ -n "$MIRROR" ]; then
  URLS="$MIRROR/https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz
$URLS"
fi

echo "== 下载 kit =="
ok=0
for u in $URLS; do
  echo "  试 $u"
  if node -e '
const fs=require("fs");
const url=process.argv[1], out=process.argv[2];
fetch(url,{signal:AbortSignal.timeout(90000)})
 .then(async r=>{ if(!r.ok) throw new Error("HTTP "+r.status);
   const b=Buffer.from(await r.arrayBuffer());
   if(b.length<1000) throw new Error("too small: "+b.length);
   fs.writeFileSync(out,b); console.log("  "+b.length+" bytes"); })
 .catch(e=>{ console.error("  "+e.message); process.exit(1) });
' "$u" "$TMP/kit.tgz"; then
    ok=1; break
  fi
done
[ "$ok" = "1" ] || { echo "ERROR: 所有下载地址都失败。网络受限时试试 --mirror https://ghfast.top" >&2; exit 1; }

echo "== 解包 =="
tar -xzf "$TMP/kit.tgz" -C "$TMP"
KIT=$(find "$TMP" -maxdepth 1 -type d -name 'dshgo-purge-kit-*' | head -1)
[ -n "$KIT" ] || { echo "ERROR: 压缩包结构异常" >&2; exit 1; }
echo "  $KIT"

echo ""
echo "== 安装 =="
cd "$KIT"
sh install.sh "$@"
