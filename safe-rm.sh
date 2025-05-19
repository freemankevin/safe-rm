#!/bin/bash
# 文件: /usr/local/bin/rm
# 用途: 防止危险的 rm 命令删除根目录或其内容
# 作者: Grok AI + 用户优化于 2025年5月16日

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 图标定义
INFO_ICON='ℹ️'
WARN_ICON='⚠️'
ERROR_ICON='❌'
SUCCESS_ICON='✅'

# 日志文件，用于记录所有 rm 操作
LOGFILE="/var/log/rm_protect.log"

# 系统关键目录列表（这些目录本身不允许删除）
PROTECTED_DIRS=(
    "/" "/bin" "/sbin" "/lib" "/lib64" "/usr" "/var" "/etc"
    "/boot" "/proc" "/sys" "/dev" "/run" "/srv" "/opt"
    "/media" "/mnt" "/tmp"
)

# 用户数据目录列表（这些目录本身需要特殊权限才能删除，但其内容可以删除）
USER_DIRS=(
    "/root" "/home" "/data"
)

# 帮助信息
show_help() {
    cat << EOF
safe-rm: 安全的文件删除工具

用法: rm [选项]... [文件]...
删除文件（从目录中删除条目）。

选项:
  -f, --force           强制删除文件，忽略不存在的文件和参数，不提示
  -i                    每次删除前提示
  -I                    删除超过三个文件或递归删除前提示
  -r, -R, --recursive   递归删除目录及其内容
  -d, --dir             删除空目录
  -v, --verbose         详细显示进行的步骤
      --help           显示此帮助信息

安全特性:
  --force              允许删除数据目录
  --verify=true        确认删除操作
  --user=root          以root用户身份执行（仅用于特定目录）

注意：此工具会阻止以下危险操作：
1. 删除根目录或在根目录下使用通配符
2. 删除系统关键目录
3. 未经授权删除数据目录

日志文件位置: /var/log/rm_protect.log

命令示例:
1. 删除用户目录下的文件（允许）：
   rm -rf /home/user/test
   rm -rf /root/test
2. 删除数据目录（需要特权）：
   rm -rf /data --force --verify=true
3. 删除系统目录（禁止）：
   rm -rf /etc（将被阻止）
   rm -rf /（将被阻止）
EOF
}

# 函数：打印带颜色和时间戳的消息
print_message() {
    local type=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $type in
        "info")
            echo -e "${BLUE}${INFO_ICON} [${timestamp}] INFO: ${message}${NC}"
            ;;
        "warn")
            echo -e "${YELLOW}${WARN_ICON} [${timestamp}] WARNING: ${message}${NC}"
            ;;
        "error")
            echo -e "${RED}${ERROR_ICON} [${timestamp}] ERROR: ${message}${NC}"
            ;;
        "success")
            echo -e "${GREEN}${SUCCESS_ICON} [${timestamp}] SUCCESS: ${message}${NC}"
            ;;
    esac
}

# 函数：记录操作日志
log_operation() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local status=$1
    local command=$2
    echo "${timestamp} - 用户: $USER - 状态: $status - 命令: $command - 目录: $PWD" >> "$LOGFILE"
}

# 函数：检查是否为受保护的系统目录
is_protected_dir() {
    local path=$1
    path="${path%/}"
    for sys_dir in "${PROTECTED_DIRS[@]}"; do
        if [[ "$path" == "$sys_dir" ]]; then
            return 0
        fi
    done
    return 1
}

# 函数：检查是否为用户数据目录
is_user_dir() {
    local path=$1
    path="${path%/}"
    for user_dir in "${USER_DIRS[@]}"; do
        if [[ "$path" == "$user_dir" ]]; then
            return 0
        fi
    done
    return 1
}

# 函数：检查路径是否为危险路径
is_dangerous_path() {
    local path=$1
    local current_dir=$2
    local force=$3
    local verify=$4
    local user=$5

    path="${path%/}"

    if [[ "$path" == -* ]]; then
        return 1
    fi

    local abs_path
    if [[ "$path" == /* ]]; then
        abs_path="$path"
    elif [[ "$path" == ./* || "$path" == ../* || "$path" == .* ]]; then
        abs_path="$(realpath -m "$current_dir/$path")"
    else
        abs_path="$(realpath -m "$current_dir/$path")"
    fi
    abs_path="${abs_path%/}"

    if [[ "$path" == "/*" || "$path" == "/"*"*" || "$abs_path" == "/" ]]; then
        return 0
    fi

    if is_protected_dir "$abs_path"; then
        return 0
    fi

    if is_user_dir "$abs_path"; then
        if [[ "$force" == "true" && "$verify" == "true" ]]; then
            return 1
        fi
        return 0
    fi

    for user_dir in "${USER_DIRS[@]}"; do
        if [[ "$abs_path" == "$user_dir"/* ]]; then
            return 1
        fi
    done

    return 1
}

# 函数：检查参数中的危险路径
check_dangerous_args() {
    local args=("$@")
    local current_dir=$(pwd)
    local force=false
    local verify=false
    local user=""

    for arg in "${args[@]}"; do
        case "$arg" in
            --force) force=true ;;
            --verify=true) verify=true ;;
            --user=*) user="${arg#--user=}" ;;
        esac
    done

    # 判断是否是在根目录下使用 .* 或 *
    if [[ "$current_dir" == "/" ]]; then
        for arg in "${args[@]}"; do
            if [[ "$arg" == "/*" || "$arg" == "."/* || "$arg" == ".."/* ]]; then
                continue
            elif [[ "$arg" == "./*" || "$arg" == "*" ]]; then
                print_message "error" "检测到危险路径: /，操作已被阻止！"
                return 1
            fi
        done
    fi

    # 检查每个参数是否为危险路径
    for arg in "${args[@]}"; do
        if [[ "$arg" == -* ]]; then
            continue
        fi

        if is_dangerous_path "$arg" "$current_dir" "$force" "$verify" "$user"; then

            local abs_path
            if [[ "$arg" == /* ]]; then
                abs_path="$arg"
            else
                abs_path="$(realpath -m "$current_dir/$arg")"
            fi
            abs_path="${abs_path%/}"

            # 统一处理根目录或通配符展开的情况
            if [[ "$arg" == "/*" || "$arg" == "/"*"*" || "$abs_path" == "/" ]]; then
                print_message "error" "检测到危险路径: /，操作已被阻止！"
                return 1
            fi

            # 如果当前在根目录下，且参数是多个受保护目录之一，则统一判定为根目录操作
            if [[ "$current_dir" == "/" && " ${PROTECTED_DIRS[*]} " =~ " $abs_path " ]]; then
                print_message "error" "检测到危险路径: /，操作已被阻止！"
                return 1
            fi

            for protected in "${PROTECTED_DIRS[@]}"; do
                if [[ "$abs_path" == "$protected" || "$abs_path" == "$protected/"* ]]; then
                    print_message "error" "检测到危险路径: $protected，操作已被阻止！"
                    return 1
                fi
            done

            for user_dir in "${USER_DIRS[@]}"; do
                if [[ "$abs_path" == "$user_dir" && ! ($force == "true" && $verify == "true") ]]; then
                    print_message "error" "检测到危险路径: $user_dir，操作已被阻止！"
                    return 1
                fi
            done

            print_message "error" "检测到危险路径: $arg，操作已被阻止！"
            return 1
        fi
    done

    return 0
}

# 安全 rm 函数，拦截危险的 rm 命令
safe_rm() {
    local args=("$@")
    local current_dir=$(pwd)

    log_operation "开始" "rm ${args[*]}"

    for arg in "${args[@]}"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            show_help
            exit 0
        fi
    done

    if ! check_dangerous_args "${args[@]}"; then
        log_operation "已阻止" "rm ${args[*]}"
        exit 1
    fi

    local force=false
    local verify=false
    local user=""
    local new_args=()
    local has_valid_args=false

    for arg in "${args[@]}"; do
        case "$arg" in
            --force)
                force=true
                ;;
            --verify=true)
                verify=true
                ;;
            --user=*)
                user="${arg#--user=}"
                ;;
            *)
                new_args+=("$arg")
                if [[ ! "$arg" =~ ^- ]]; then
                    has_valid_args=true
                fi
                ;;
        esac
    done

    if ! $has_valid_args; then
        print_message "error" "未提供有效的文件或目录"
        log_operation "失败" "rm ${new_args[*]}"
        exit 1
    fi

    local file_exists=false
    for arg in "${new_args[@]}"; do
        if [[ "$arg" != -* && -e "$arg" ]]; then
            file_exists=true
            break
        fi
    done

    if ! $file_exists; then
        print_message "error" "指定的文件或目录不存在"
        log_operation "失败" "rm ${new_args[*]}"
        exit 1
    fi

    log_operation "允许" "rm ${new_args[*]}"
    print_message "success" "执行删除操作: /bin/rm.original ${new_args[*]}"
    /bin/rm.original "${new_args[@]}"
}

# 初始化日志文件并设置权限
if [[ ! -f "$LOGFILE" ]]; then
    touch "$LOGFILE"
    chmod 640 "$LOGFILE"
    chown root:adm "$LOGFILE"
fi

# 调用 safe_rm 函数处理所有参数
safe_rm "$@"