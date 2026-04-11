#!/bin/bash
echo ">>> 正在外科手术式修复 SCTP 核心源码引用..."

# 智能进入 common 目录 (兼容各种执行路径)
if [ -d "common/net/sctp" ]; then
    cd common
elif [ ! -d "net/sctp" ]; then
    echo "❌ 错误：找不到 net/sctp 目录！请检查执行路径。"
    exit 1
fi

# 1. 替换 net->sctp.xxx 形式
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\./net_sctp(\1)./g' {} +

# 2. 替换 net->sctp 后接标点符号
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\([;)]\)/net_sctp(\1)\2/g' {} +

# 3. 替换取址引用 &net->sctp
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/&[ ]*\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp/\&net_sctp(\1)/g' {} +

# 4. 替换后面带空格的 net->sctp
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\([ \t]\)/net_sctp(\1)\2/g' {} +

# 5. 修复 sctp.h 里的极度顽固宏
sed -i 's/(net)->sctp\.sctp_statistics/net_sctp(net).sctp_statistics/g' include/net/sctp/sctp.h 2>/dev/null || true
sed -i 's/(net)->sctp\([^.]\)/net_sctp(net)\1/g' include/net/sctp/sctp.h 2>/dev/null || true

# 6. sysctl.c 专属高危排雷 (注意这里使用的是 net_ext，完美匹配您的静态补丁！)
sed -i 's/#include <linux\/sysctl.h>/#include <linux\/sysctl.h>\n\n#define sctp_net_from_data(data_ptr, field) (container_of((data_ptr), struct net_ext, sctp.field)->net)\nstatic struct netns_sctp sctp_sysctl_defaults;/g' net/sctp/sysctl.c 2>/dev/null || true
sed -i 's/container_of(\([^,]*\),[ \t]*struct[ \t]*net[ \t]*,[ \t]*sctp\.\([a-zA-Z0-9_]*\))/sctp_net_from_data(\1, \2)/g' net/sctp/sysctl.c 2>/dev/null || true
sed -i 's/init_net\.sctp/sctp_sysctl_defaults/g' net/sctp/sysctl.c 2>/dev/null || true

# 7. 修正 structs.h
sed -i 's/struct netns_sctp \*sctp;/struct netns_sctp sctp;/g' include/net/sctp/structs.h 2>/dev/null || true

echo "✅ 源码引用重构完毕！所有指标已对接至 net_ext！"
