#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图标定义
INFO='ℹ️'
WARN='⚠️'
ERROR='❌'
SUCCESS='✅'

# 日志函数
log() {
    local type=$1 message=$2
    local timestamp=$(/usr/bin/date '+%Y-%m-%d %H:%M:%S')
    case $type in
        info)    echo -e "${BLUE}${INFO} [$timestamp] 信息: $message${NC}" ;;
        warn)    echo -e "${YELLOW}${WARN} [$timestamp] 警告: $message${NC}" ;;
        error)   echo -e "${RED}${ERROR} [$timestamp] 错误: $message${NC}"; exit 1 ;;
        success) echo -e "${GREEN}${SUCCESS} [$timestamp] 成功: $message${NC}" ;;
    esac
}

# 检查是否已安装
is_installed() {
    [[ -f "/usr/local/bin/rm" && -f "/bin/rm.original" ]]
}

# 确保 root 权限
[[ "$(id -u)" != "0" ]] && log error "此脚本需要 root 权限"

# 创建临时目录
tmp_dir=$(/usr/bin/mktemp -d)
log info "创建临时目录: $tmp_dir"

# 复制 safe-rm 脚本
/usr/bin/cp safe-rm.sh "${tmp_dir}/safe-rm" || log error "无法复制 safe-rm.sh"
/usr/bin/chmod 755 "${tmp_dir}/safe-rm"

# 创建配置脚本
/usr/bin/cat > "${tmp_dir}/config.sh" << 'EOF'
#!/bin/bash
# safe-rm 配置文件
# 可自定义受保护目录和日志设置

# 额外受保护的系统目录
EXTRA_PROTECTED_DIRS=()

# 额外用户数据目录
EXTRA_USER_DIRS=()

# 日志文件路径
LOGFILE="/var/log/rm_protect.log"
EOF

# 创建安装脚本
/usr/bin/cat > "${tmp_dir}/install.sh" << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 图标定义
INFO='ℹ️'
WARN='⚠️'
ERROR='❌'
SUCCESS='✅'

# 日志函数
log() {
    local type=$1 message=$2
    local timestamp=$(/usr/bin/date '+%Y-%m-%d %H:%M:%S')
    case $type in
        info)    echo -e "${BLUE}${INFO} [$timestamp] 信息: $message${NC}" ;;
        warn)    echo -e "${YELLOW}${WARN} [$timestamp] 警告: $message${NC}" ;;
        error)   echo -e "${RED}${ERROR} [$timestamp] 错误: $message${NC}"; exit 1 ;;
        success) echo -e "${GREEN}${SUCCESS} [$timestamp] 成功: $message${NC}" ;;
    esac
}

# 检查是否已安装
is_installed() {
    [[ -f "/usr/local/bin/rm" && -f "/bin/rm.original" ]]
}

# 测试函数
test_safe_rm() {
    log info "开始测试 safe-rm 功能..."

    local test_cases=(
        "rm /root /root/ -rf"
        "rm /home /home/ -rf"
        "rm /data /data/ -rf"
        "rm /* -rf"
        "rm -rf /*"
        "cd / && rm ./* -rf"
        "cd / && rm -rf ./*"
        "rm /etc/ /etc -rf"
    )

    local failed=0
    for test in "${test_cases[@]}"; do
        log info "执行测试: $test"
        if eval "$test" >/dev/null 2>&1; then
            log warn "测试失败: $test 未被阻止"
            ((failed++))
        else
            log success "测试通过: $test 已阻止"
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log success "所有测试用例通过"
    else
        log error "$failed 个测试用例失败"
    fi
}

# 卸载函数
uninstall_safe_rm() {
    if is_installed; then
        log info "开始卸载 safe-rm..."

        # 禁用 rm 别名并移除 /usr/local/bin 从 PATH
        unalias rm 2>/dev/null
        export PATH=$(echo "$PATH" | sed -E 's;:/usr/local/bin;;g')

        # 恢复原始 rm
        if [[ -f /bin/rm.original ]]; then
            /usr/bin/mv /bin/rm.original /bin/rm || log error "无法恢复原始 rm"
            log info "已恢复原始 rm 至 /bin/rm"
        else
            log warn "未找到 /bin/rm.original"
        fi

        # 删除 PATH 配置文件
        if [[ -f /etc/profile.d/safe-rm.sh ]]; then
            /usr/bin/rm -f /etc/profile.d/safe-rm.sh
            if [[ $? -eq 0 ]]; then
                log info "已删除 PATH 配置文件"
                source /etc/profile
                log info "已更新环境变量"
            else
                log warn "无法删除 /etc/profile.d/safe-rm.sh，继续卸载"
            fi
        else
            log warn "未找到 /etc/profile.d/safe-rm.sh"
        fi

        # 删除 safe-rm
        if [[ -f /usr/local/bin/rm ]]; then
            /usr/bin/rm -f /usr/local/bin/rm || log error "无法删除 /usr/local/bin/rm"
            log info "已删除 /usr/local/bin/rm"
        else
            log warn "未找到 /usr/local/bin/rm"
        fi

        log success "safe-rm 卸载完成" 
        source /etc/profile
    else
        log info "safe-rm 未安装，无需卸载"
    fi
}

# 安装函数
install_safe_rm() {
    if is_installed; then
        log info "safe-rm 已安装，跳过安装"
        return 0
    fi

    log info "开始安装 safe-rm..."

    # 备份原始 rm
    if [[ ! -f /bin/rm.original ]]; then
        /usr/bin/mv /bin/rm /bin/rm.original || log error "无法备份原始 rm"
        log info "已备份原始 rm 至 /bin/rm.original"
    fi

    # 安装 safe-rm
    /usr/bin/cp safe-rm /usr/local/bin/rm || log error "无法复制 safe-rm"
    /usr/bin/chmod 755 /usr/local/bin/rm
    /usr/bin/chown root:root /usr/local/bin/rm
    log info "已安装 safe-rm 至 /usr/local/bin/rm"

    # 配置 PATH
    if [[ ! -f /etc/profile.d/safe-rm.sh ]]; then
        log info "配置 PATH 环境变量"
        echo 'export PATH=/usr/local/bin:$PATH' > /etc/profile.d/safe-rm.sh
        /usr/bin/chmod 755 /etc/profile.d/safe-rm.sh
        source /etc/profile.d/safe-rm.sh
        log info "已配置 PATH 环境变量"
    fi

    log success "safe-rm 安装完成"

    # 执行测试
    test_safe_rm
}

# 主逻辑
case "$1" in
    "--uninstall")
        uninstall_safe_rm
        ;;
    *)
        install_safe_rm
        ;;
esac
EOF

/usr/bin/chmod 755 "${tmp_dir}/install.sh"

# 尝试编译 install.sh 为二进制
if /usr/bin/command -v shc >/dev/null; then
    log info "编译 install.sh 为二进制..."
    shc -f "${tmp_dir}/install.sh" -o "${tmp_dir}/install" || log error "编译失败"
    /usr/bin/chmod 755 "${tmp_dir}/install"
else
    log warn "未找到 shc，保留 install.sh 作为安装脚本"
    /usr/bin/mv "${tmp_dir}/install.sh" "${tmp_dir}/install"
fi

# 创建打包文件
package_name="safe-rm.tar.gz"
/usr/bin/tar -czf "$package_name" -C "$tmp_dir" safe-rm config.sh install || log error "无法创建打包文件"

# 清理临时目录
/usr/bin/rm -rf "$tmp_dir"

# 显示部署说明
log success "打包文件已创建: $package_name"
/usr/bin/cat << EOF

部署说明：
1. 将 $package_name 复制到目标服务器
2. 解压：tar -xzf $package_name
3. 可选：编辑 config.sh 自定义受保护目录或日志路径
4. 运行安装：./install
5. 卸载：./install --uninstall

EOF