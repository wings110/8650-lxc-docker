#!/bin/bash
cd common

# 修复所有 SCTP 文件中的指针引用
find net/sctp -name "*.c" -exec sed -i 's/struct netns_sctp \*sn = net->sctp;/struct netns_sctp *sn = \&net->sctp;/g' {} \;
find net/sctp -name "*.c" -exec sed -i 's/struct netns_sctp \*sn = net->sctp;/struct netns_sctp *sn = \&net->sctp;/g' {} \;

# 修复头文件
sed -i 's/struct netns_sctp \*sctp;/struct netns_sctp sctp;/g' include/net/sctp/structs.h 2>/dev/null || true

echo "✅ SCTP ABI 兼容性修复完成"
