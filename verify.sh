#!/bin/sh
# 体检：确认引擎在跑、插件是实体目录、破甲真的被加载。
set -u

DSH_HOME=${DSH_HOME:-$HOME/.dsh}
PROFILE=${PROFILE:-web}
P="$DSH_HOME/profiles/$PROFILE"
NM="$P/node_modules"

ok=0
bad=0
chk() { # chk <描述> <命令...>
  desc=$1; shift
  if "$@" >/dev/null 2>&1; then
    printf '  [OK]   %s\n' "$desc"; ok=$((ok+1))
  else
    printf '  [FAIL] %s\n' "$desc"; bad=$((bad+1))
  fi
}

echo "== 文件 =="
chk "node_modules/dsh-purge 是实体目录"             test -d "$NM/dsh-purge"
chk "node_modules/dsh-purge 不是软链"               test ! -L "$NM/dsh-purge"
chk "node_modules/local-purge 是实体目录"           test -d "$NM/local-purge"
chk "node_modules/local-purge 不是软链"             test ! -L "$NM/local-purge"
chk "dsh-go/plugins/local-purge 源码在"             test -d "$DSH_HOME/dsh-go/plugins/local-purge"

# 下面三项要引擎跑过一次才会有，属于「待生效」而不是「坏了」
pending=0
if [ -f "$DSH_HOME/dsh-purge/installed-rev" ]; then
  printf '  [OK]   installed-rev 存在\n'; ok=$((ok+1))
else
  printf '  [WAIT] installed-rev 还没生成（重启引擎后出现）\n'; pending=$((pending+1))
fi
if [ -s "$DSH_HOME/prompt-inject.md" ]; then
  printf '  [OK]   %s\n' "$DSH_HOME/prompt-inject.md 非空"; ok=$((ok+1))
else
  printf '  [WAIT] prompt-inject.md 还没生成（重启引擎后出现）\n'; pending=$((pending+1))
fi
if [ -f "$DSH_HOME/dsh-go/local-purge.loaded.json" ]; then
  printf '  [OK]   原生壳加载标记存在\n'; ok=$((ok+1))
else
  printf '  [WAIT] 原生壳加载标记还没生成（重启引擎后出现）\n'; pending=$((pending+1))
fi

echo ""
echo "== profile =="
if [ -f "$P/package.json" ]; then
  for n in dsh-purge local-purge; do
    if grep -q "\"$n\"" "$P/package.json"; then
      printf '  [OK]   bundles 里登记了 %s\n' "$n"; ok=$((ok+1))
    else
      printf '  [FAIL] bundles 里没有 %s\n' "$n"; bad=$((bad+1))
    fi
  done
else
  printf '  [FAIL] %s/package.json 不存在\n' "$P"; bad=$((bad+1))
fi

echo ""
echo "== 内容 =="
[ -f "$DSH_HOME/dsh-purge/installed-rev" ] && printf '  rev    = %s\n' "$(cat "$DSH_HOME/dsh-purge/installed-rev")"
[ -f "$DSH_HOME/prompt-inject.md" ] && printf '  注入   = %s 字节\n' "$(wc -c < "$DSH_HOME/prompt-inject.md" | tr -d ' ')"
[ -f "$DSH_HOME/dsh-go/local-purge.loaded.json" ] && {
  printf '  原生壳 = '; tr -d '\n' < "$DSH_HOME/dsh-go/local-purge.loaded.json"; echo
}

echo ""
if [ "$bad" -eq 0 ] && [ "$pending" -eq 0 ]; then
  echo "全部通过（$ok 项）。"
  echo "如果 App 里还看不到状态条：设置 › 本机引擎 › 重启引擎，再把 App 划掉重开。"
  exit 0
elif [ "$bad" -eq 0 ]; then
  echo "文件与注册都对了（$ok 项通过），还有 $pending 项要引擎跑一次才出现。"
  echo "下一步：设置 › 本机引擎 › 重启引擎，再跑一次 sh verify.sh。"
  exit 0
else
  echo "有 $bad 项没通过。看 docs/troubleshooting.md。"
  exit 1
fi
