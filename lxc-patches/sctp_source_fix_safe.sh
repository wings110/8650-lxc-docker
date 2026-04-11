#!/bin/bash
echo ">>> 正在外科手术式修复 SCTP 核心源码引用..."

# 进入 common 目录（如果脚本在根目录执行）
if [ -d "common" ]; then
    cd common
fi

echo "当前工作目录: $(pwd)"

# 1. 替换直接引用: net->sctp. 和 (net)->sctp. 宏
echo ">>> 步骤 1: 替换直接引用..."
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\./net_sctp(\1)./g' {} +

# 2. 替换取址引用: &net->sctp (解决地址偏移计算)
echo ">>> 步骤 2: 替换取址引用..."
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/&[ ]*\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp/\&net_sctp(\1)/g' {} +

# 3. 修复 sctp.h 中的统计宏（关键！修复编译错误）
echo ">>> 步骤 3: 修复 sctp.h 中的统计宏..."
if [ -f "include/net/sctp/sctp.h" ]; then
    # 修复 SCTP_INC_STATS 宏
    sed -i 's/(net)->sctp\.sctp_statistics/net_sctp(net).sctp_statistics/g' include/net/sctp/sctp.h
    sed -i 's/(net)->sctp\([^.]\)/net_sctp(net)\1/g' include/net/sctp/sctp.h
    echo "   ✅ sctp.h 宏定义已修复"
else
    echo "   ⚠️ include/net/sctp/sctp.h 不存在"
fi

# 4. 修复其他头文件中的 net->sctp 引用
echo ">>> 步骤 4: 修复其他头文件..."
find include/net/sctp -name "*.h" -type f 2>/dev/null | while read file; do
    if grep -q "net->sctp" "$file" 2>/dev/null; then
        echo "   修复: $file"
        sed -i 's/\([^a-zA-Z]\)net->sctp\./\1net_sctp(net)./g' "$file"
        sed -i 's/\([^a-zA-Z]\)net->sctp\([^.]\)/\1net_sctp(net)\2/g' "$file"
    fi
done

# 5. sysctl.c 专属高危排雷 (修复 container_of 反向指针寻址崩溃)
echo ">>> 步骤 5: 修复 sysctl.c..."
if [ -f "net/sctp/sysctl.c" ]; then
    sed -i 's/#include <linux\/sysctl.h>/#include <linux\/sysctl.h>\n\n#define sctp_net_from_data(data_ptr, field) (container_of((data_ptr), struct net_ext, sctp.field)->net)\nstatic struct netns_sctp sctp_sysctl_defaults;/g' net/sctp/sysctl.c
    sed -i 's/container_of(\([^,]*\),[ \t]*struct[ \t]*net[ \t]*,[ \t]*sctp\.\([a-zA-Z0-9_]*\))/sctp_net_from_data(\1, \2)/g' net/sctp/sysctl.c
    sed -i 's/init_net\.sctp/sctp_sysctl_defaults/g' net/sctp/sysctl.c
    echo "   ✅ sysctl.c 修复完成"
else
    echo "   ⚠️ net/sctp/sysctl.c 不存在"
fi

# 6. 修复 protocol.c
echo ">>> 步骤 6: 修复 protocol.c..."
if [ -f "net/sctp/protocol.c" ]; then
    sed -i 's/struct netns_sctp \*sn = net->sctp;/struct netns_sctp *sn = \&net->sctp;/g' net/sctp/protocol.c 2>/dev/null || true
    echo "   ✅ protocol.c 修复完成"
fi

# 7. 修复 socket.c
echo ">>> 步骤 7: 修复 socket.c..."
if [ -f "net/sctp/socket.c" ]; then
    sed -i 's/struct netns_sctp \*sn = net->sctp;/struct netns_sctp *sn = \&net->sctp;/g' net/sctp/socket.c 2>/dev/null || true
    echo "   ✅ socket.c 修复完成"
fi

# 8. 修复 structs.h
echo ">>> 步骤 8: 修复 structs.h..."
if [ -f "include/net/sctp/structs.h" ]; then
    sed -i 's/struct netns_sctp \*sctp;/struct netns_sctp sctp;/g' include/net/sctp/structs.h 2>/dev/null || true
    echo "   ✅ structs.h 修复完成"
fi

echo ""
echo "========== 修复完成统计 =========="
echo "包含 net_sctp 宏的代码行数:"
grep -r "net_sctp" net/sctp include/net/sctp --include="*.[ch]" 2>/dev/null | wc -l | xargs echo "  总计:"

echo ""
echo "✅ SCTP 源码引用重构完毕！"
