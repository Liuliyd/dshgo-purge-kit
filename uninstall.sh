#!/bin/sh
# 移除 dsh-purge + local-purge。profile 备份保留，可手工恢复。
set -eu

DSH_HOME=${DSH_HOME:-$HOME/.dsh}
PROFILE=${PROFILE:-web}
P="$DSH_HOME/profiles/$PROFILE"
NM="$P/node_modules"
STAMP=$(date +%Y%m%d-%H%M%S)

[ -d "$P" ] || { echo "找不到 $P" >&2; exit 1; }

echo "== 备份当前 profile =="
BAK="$DSH_HOME/profiles/$PROFILE.bak-$STAMP"
cp -a "$P" "$BAK"
echo "backup = $BAK"

echo "== 移除插件目录 =="
rm -rf "$NM/dsh-purge" "$NM/local-purge"
echo "  node_modules/dsh-purge, node_modules/local-purge"

echo "== 从 bundles 摘掉 =="
node -e '
const fs=require("fs");
const p=process.argv[1];
const j=JSON.parse(fs.readFileSync(p,"utf8"));
const drop=new Set(["dsh-purge","local-purge"]);
if(j.dsh?.profile?.bundles) j.dsh.profile.bundles=j.dsh.profile.bundles.filter(b=>!drop.has(b));
if(j.dependencies) for(const k of drop) delete j.dependencies[k];
fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");
console.log("  bundles =", (j.dsh?.profile?.bundles||[]).join(", "));
' "$P/package.json"

echo "== 保留的状态（要彻底清掉再手动删） =="
echo "  $DSH_HOME/dsh-purge"
echo "  $DSH_HOME/redteam"
echo "  $DSH_HOME/prompt-inject.md"
echo "  $DSH_HOME/.agent-presets/redteam"
echo "  $DSH_HOME/dsh-go/plugins/local-purge"

echo ""
echo "下一步：设置 › 本机引擎 › 重启引擎"
