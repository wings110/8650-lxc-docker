#!/bin/bash
echo ">>> 正在外科手术式修复 SCTP 核心源码引用..."

# 进入 common 目录（如果脚本在根目录执行）
if [ -d "common" ]; then
    cd common
fi

echo "当前工作目录: $(pwd)"

# ============================================
# 1. 修复所有 .c 和 .h 文件中的 net->sctp 引用
# ============================================
echo ">>> 步骤 1: 修复所有 net->sctp 引用..."

# 1.1 修复 net->sctp.xxx 形式
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\./net_sctp(\1)./g' {} +

# 1.2 修复 net->sctp 后面没有点的情况（分号、括号、空格等）
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\([;)]\)/net_sctp(\1)\2/g' {} +

# 1.3 修复取址引用 &net->sctp
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/&[ ]*\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp/\&net_sctp(\1)/g' {} +

# 1.4 修复单独出现的 net->sctp（后面是空格或行尾）
find net/sctp include/net/sctp -type f -name "*.[ch]" -exec sed -i 's/\([a-zA-Z0-9_>\[\]\.\(\)\-]*\)->sctp\([ \t]\)/net_sctp(\1)\2/g' {} +

# ============================================
# 2. 修复 sctp.h 中的统计宏（关键！）
# ============================================
echo ">>> 步骤 2: 修复 sctp.h 中的统计宏..."
if [ -f "include/net/sctp/sctp.h" ]; then
    # 修复 SCTP_INC_STATS 宏
    sed -i 's/(net)->sctp\.sctp_statistics/net_sctp(net).sctp_statistics/g' include/net/sctp/sctp.h
    sed -i 's/(net)->sctp\([^.]\)/net_sctp(net)\1/g' include/net/sctp/sctp.h
    
    # 修复 SCTP_DEC_STATS 宏（如果存在）
    sed -i 's/(net)->sctp\.sctp_statistics/net_sctp(net).sctp_statistics/g' include/net/sctp/sctp.h
    
    # 修复其他可能的统计宏
    sed -i 's/(net)->sctp\./net_sctp(net)./g' include/net/sctp/sctp.h
    echo "   ✅ sctp.h 宏定义已修复"
else
    echo "   ⚠️ include/net/sctp/sctp.h 不存在"
fi

# ============================================
# 3. 修复所有头文件中的 net->sctp 引用
# ============================================
echo ">>> 步骤 3: 修复所有头文件..."
find include/net/sctp -name "*.h" -type f 2>/dev/null | while read file; do
    if grep -q "net->sctp" "$file" 2>/dev/null; then
        echo "   修复: $file"
        sed -i 's/\([^a-zA-Z]\)net->sctp\./\1net_sctp(net)./g' "$file"
        sed -i 's/\([^a-zA-Z]\)net->sctp\([^.]\)/\1net_sctp(net)\2/g' "$file"
    fi
done

# ============================================
# 4. 修复 sysctl.c
# ============================================
echo ">>> 步骤 4: 修复 sysctl.c..."
if [ -f "net/sctp/sysctl.c" ]; then
    sed -i 's/#include <linux\/sysctl.h>/#include <linux\/sysctl.h>\n\n#define sctp_net_from_data(data_ptr, field) (container_of((data_ptr), struct net_ext, sctp.field)->net)\nstatic struct netns_sctp sctp_sysctl_defaults;/g' net/sctp/sysctl.c
    sed -i 's/container_of(\([^,]*\),[ \t]*struct[ \t]*net[ \t]*,[ \t]*sctp\.\([a-zA-Z0-9_]*\))/sctp_net_from_data(\1, \2)/g' net/sctp/sysctl.c
    sed -i 's/init_net\.sctp/sctp_sysctl_defaults/g' net/sctp/sysctl.c
    echo "   ✅ sysctl.c 修复完成"
fi

# ============================================
# 5. 修复所有 .c 文件中的 struct netns_sctp *sn = net->sctp 模式
# ============================================
echo ">>> 步骤 5: 修复所有 .c 文件中的指针引用..."
find net/sctp -name "*.c" -type f -exec sed -i 's/struct netns_sctp \*sn = net->sctp;/struct netns_sctp *sn = \&net->sctp;/g' {} \;

# 额外的通用修复：任何 net->sctp 出现的地方
find net/sctp -name "*.c" -type f -exec sed -i 's/net->sctp/net_sctp(net)/g' {} \;

# ============================================
# 6. 修复 structs.h
# ============================================
echo ">>> 步骤 6: 修复 structs.h..."
if [ -f "include/net/sctp/structs.h" ]; then
    sed -i 's/struct netns_sctp \*sctp;/struct netns_sctp sctp;/g' include/net/sctp/structs.h 2>/dev/null || true
    echo "   ✅ structs.h 修复完成"
fi

# ============================================
# 7. 验证关键文件的修复
# ============================================
echo ""
echo "========== 验证关键文件修复 =========="

# 检查 sctp.h
if grep -q "net_sctp(net)" include/net/sctp/sctp.h 2>/dev/null; then
    echo "✅ sctp.h - 已修复"
else
    echo "❌ sctp.h - 未修复（会导致编译错误！）"
fi

# 检查是否还有残留的 net->sctp
echo ""
echo "残留的 net->sctp 引用（应该为0）:"
grep -r "net->sctp" net/sctp include/net/sctp --include="*.[ch]" 2>/dev/null | grep -v "net_sctp" | wc -l | xargs echo "  数量:"

if grep -r "net->sctp" net/sctp include/net/sctp --include="*.[ch]" 2>/dev/null | grep -v "net_sctp" | grep -q .; then
    echo ""
    echo "⚠️ 仍有残留的 net->sctp 引用："
    grep -r "net->sctp" net/sctp include/net/sctp --include="*.[ch]" 2>/dev/null | grep -v "net_sctp" | head -10
fi

echo ""
echo "========== 修复完成统计 =========="
echo "包含 net_sctp 宏的代码行数:"
grep -r "net_sctp" net/sctp include/net/sctp --include="*.[ch]" 2>/dev/null | wc -l | xargs echo "  总计:"

echo ""
echo "✅ SCTP 源码引用重构完毕！"
