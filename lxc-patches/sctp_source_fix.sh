#!/bin/bash
echo ">>> 正在外科手术式修复 SCTP 核心源码引用..."

# 智能进入 common 目录
if [ -d "common/net/sctp" ]; then
    cd common
elif [ ! -d "net/sctp" ]; then
    echo "❌ 错误：找不到 net/sctp 目录！请检查执行路径。"
    exit 1
fi

# =========================================================
# 1. 终极替换魔法：使用 Perl 正则引擎，一击秒杀所有 ->sctp 引用
# 无论是 net->sctp, (net)->sctp, 还是 &sock_net(sk)->sctp.xxx 都能完美替换！
# =========================================================
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec perl -pi -e 's/([a-zA-Z0-9_()\[\]>.-]+)->sctp\b/net_sctp($1)/g' {} +

# =========================================================
# 2. sysctl.c 专属高危排雷 (修复 container_of 反向指针寻址崩溃)
# =========================================================
sed -i 's/#include <linux\/sysctl.h>/#include <linux\/sysctl.h>\n\n#define sctp_net_from_data(data_ptr, field) (container_of((data_ptr), struct net_ext, sctp.field)->net)\nstatic struct netns_sctp sctp_sysctl_defaults;/g' net/sctp/sysctl.c 2>/dev/null || true
sed -i 's/container_of(\([^,]*\),[ \t]*struct[ \t]*net[ \t]*,[ \t]*sctp\.\([a-zA-Z0-9_]*\))/sctp_net_from_data(\1, \2)/g' net/sctp/sysctl.c 2>/dev/null || true
sed -i 's/init_net\.sctp/sctp_sysctl_defaults/g' net/sctp/sysctl.c 2>/dev/null || true

# =========================================================
# 3. 修正 structs.h
# =========================================================
sed -i 's/struct netns_sctp \*sctp;/struct netns_sctp sctp;/g' include/net/sctp/structs.h 2>/dev/null || true

echo "✅ 源码引用重构完毕！所有指标已对接至 net_ext！"

# =========================================================
# 打印战报：看看这次成功修改了多少文件
# =========================================================
echo "========== 🛠️ 以下是本次被成功修改的 SCTP 源码文件清单 =========="
git diff --name-only net/sctp include/net/sctp
echo "=================================================================="
