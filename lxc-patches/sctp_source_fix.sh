#!/bin/bash
echo ">>> 正在外科手术式修复 SCTP 核心源码引用..."

# 1. 替换直接引用: net->sctp. 和 (net)->sctp. 宏
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\./net_sctp(\1)./g' {} +

# 2. 替换取址引用: &net->sctp (解决地址偏移计算)
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/&[ ]*\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp/\&net_sctp(\1)/g' {} +

# 3. sysctl.c 专属高危排雷 (修复 container_of 反向指针寻址崩溃)
# 【注意】这里已经更换为 net_ext，完美匹配探针修改的背包！
sed -i 's/#include <linux\/sysctl.h>/#include <linux\/sysctl.h>\n\n#define sctp_net_from_data(data_ptr, field) (container_of((data_ptr), struct net_ext, sctp.field)->net)\nstatic struct netns_sctp sctp_sysctl_defaults;/g' net/sctp/sysctl.c
sed -i 's/container_of(\([^,]*\),[ \t]*struct[ \t]*net[ \t]*,[ \t]*sctp\.\([a-zA-Z0-9_]*\))/sctp_net_from_data(\1, \2)/g' net/sctp/sysctl.c
sed -i 's/init_net\.sctp/sctp_sysctl_defaults/g' net/sctp/sysctl.c

echo "✅ 源码引用重构完毕！"
