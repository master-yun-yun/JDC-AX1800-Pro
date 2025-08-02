#  QCA #318编译叫脚本----到31行--- " ---##--- " 恢复取消"##" #
###!/usr/bin/env bash
##set -e

##echo ">>> 开始修复 gettext-full / gperf 等 host 构建失败..."

##cd "$(dirname "$0")/../wrt"

### 1. 生成 .config
##[ -f .config ] || make defconfig

### 2. 分步预编译 host 工具链（串行编译）
##echo ">>> 预编译 host 工具链 ..."
##make tools/install
##make toolchain/install

### 3. 彻底清理残留文件
##echo ">>> 清理残留缓存 ..."
##rm -rf build_dir/hostpkg/* staging_dir/hostpkg/* tmp/*

### 4. 设置环境变量
##export LIBINTL=1
##export BISON_LOCALEDIR=/usr/share/locale
##export PATH=/mnt/build_wrt/staging_dir/host/bin:$PATH

### 5. 分步编译 gettext-full/host
##echo ">>> 编译 gettext-full ..."
##make package/libs/gettext-full/host/clean
##make package/libs/gettext-full/host/compile V=s && echo "gettext-full 编译成功" || { echo "gettext-full 编译失败"; exit 1; }

##echo ">>> gettext-full host 修复完成！"

# --------------------deepseek优化版本---------------------------- 3
#!/usr/bin/env bash
# fix_host_deps.sh - 高效修复 OpenWRT host 依赖问题（优化版）

set -euo pipefail

# ================= 配置区域 =================
MAX_JOBS=${MAX_JOBS:-$(nproc)}                # 默认使用物理核心数
TOOLCHAIN_JOBS=${TOOLCHAIN_JOBS:-2}           # 工具链编译使用保守并行度
LOG_DIR="${LOG_DIR:-logs}"                     # 日志存储目录
ERROR_SUMMARY_LINES=30                        # 错误摘要显示行数
# ============================================

# ============== 颜色输出 ==============
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
status() { echo -e "${BLUE}[STATUS]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()    { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# 实时日志输出函数
tail_log() {
  local log_file=$1
  local marker=${2:-""}
  
  # 等待日志文件创建
  while [ ! -f "$log_file" ]; do sleep 1; done
  
  echo -e "${CYAN}==== 开始追踪日志: ${log_file} ${marker} ====${NC}"
  tail -n 0 -f "$log_file" &
  local tail_pid=$!
  
  # 返回PID以便后续停止
  echo $tail_pid
}

# 显示错误摘要
show_error_summary() {
  local log_file=$1
  echo -e "\n${RED}======= 错误摘要 =======${NC}"
  grep --color=always -iE 'error:|fail|undefined|missing|no such|recipe for target' "$log_file" | tail -n $ERROR_SUMMARY_LINES
  echo -e "${RED}=======================${NC}"
  
  # 显示最后的关键行
  echo -e "\n${YELLOW}======= 日志尾部 =======${NC}"
  tail -n $((ERROR_SUMMARY_LINES/2)) "$log_file" | awk '{print NR ": " $0}'
  echo -e "${YELLOW}=======================${NC}\n"
}

# 带资源监控的编译函数
compile_with_monitor() {
  local pkg_path=$1
  local log_file=$2
  local jobs=$3
  
  # 启动资源监控后台进程
  local monitor_log="${log_file}.monitor"
  (while true; do
    echo "==== [$(date +%H:%M:%S)] 系统负载 ===="
    echo "内存使用: $(free -m | awk '/Mem:/ {printf "%.1f%% (%dMB free)", $3/$2*100, $4}')"
    echo "交换空间: $(free -m | awk '/Swap:/ {printf "%.1f%% (%dMB free)", $3/$2*100, $4}')"
    echo "磁盘空间: $(df -h . | awk 'NR==2 {print $4 " free"}')"
    echo "负载平均: $(uptime | awk -F'[a-z]:' '{print $2}')"
    echo "进程状态: $(ps -eo pid,ppid,pcpu,pmem,comm | grep -E 'make|gcc|g\+\+' | grep -v grep || echo '无编译进程')"
    sleep 10
  done) > "$monitor_log" 2>&1 &
  local monitor_pid=$!
  
  # 执行编译
  set +e
  time make "$pkg_path/clean" >/dev/null 2>&1
  time make "$pkg_path/compile" -j$jobs V=s > "$log_file" 2>&1
  local exit_code=$?
  set -e
  
  # 停止监控
  kill $monitor_pid 2>/dev/null || true
  
  return $exit_code
}

# 工具链编译函数
compile_toolchain() {
  local target=$1
  local log_file="${LOG_DIR}/${target//\//_}.log"
  
  mkdir -p "$(dirname "$log_file")"
  [ -f "$log_file" ] && mv "$log_file" "${log_file}.old"
  
  status "编译 $target (并行度: ${TOOLCHAIN_JOBS})"
  status "日志文件: ${log_file}"
  
  # 启动日志追踪
  local tail_pid=$(tail_log "$log_file" "$target")
  
  # 执行编译
  set +e
  time make $target -j${TOOLCHAIN_JOBS} V=s > "$log_file" 2>&1
  local exit_code=$?
  set -e
  
  # 停止日志追踪
  kill $tail_pid 2>/dev/null || true
  
  if [ $exit_code -eq 0 ]; then
    log "$target 编译成功"
    echo "[SUCCESS] $(date)" >> "$log_file"
    return 0
  else
    show_error_summary "$log_file"
    die "$target 编译失败！请查看完整日志: ${log_file}"
  fi
}

# ============== 主程序 ==============
main() {
  # 基础检查
  : ${WRT_DIR:="$(cd "$(dirname "$0")/../wrt" && pwd)"}
  cd "${WRT_DIR}" || die "无法进入目录: ${WRT_DIR}"
  [ -f Makefile ] || die "未在 wrt 根目录发现 Makefile"
  
  # 创建日志目录
  LOG_DIR="${WRT_DIR}/${LOG_DIR}"
  mkdir -p "$LOG_DIR"
  
  # 显示系统信息
  log "系统信息: $(uname -a)"
  log "处理器: $(nproc) 核心"
  log "内存: $(free -h | awk '/Mem:/{print $2}')"
  status "最大并行任务数: ${MAX_JOBS}"
  status "工具链并行度: ${TOOLCHAIN_JOBS}"
  status "日志目录: ${LOG_DIR}"

  # 0. 生成 .config
  if [ ! -f .config ]; then
    status "生成默认 .config ..."
    make defconfig > "${LOG_DIR}/defconfig.log" 2>&1
  fi

  # 1. 预编译 host 工具链（保守并行）
  status "预编译 host 工具链 (使用保守并行度 ${TOOLCHAIN_JOBS})"
  compile_toolchain "tools/install"
  compile_toolchain "toolchain/install"

  # 2. 清理残留缓存
  status "清理残留缓存 ..."
  clean_targets=(
    build_dir/hostpkg/gettext-*
    build_dir/hostpkg/gperf-*
    staging_dir/hostpkg/stamp/.gettext-full_installed
    staging_dir/hostpkg/stamp/.gperf_installed
    tmp/.packagedeps*
    tmp/info/.packageinfo-*
    tmp/stage-*
    tmp/run-*
  )

  for target in "${clean_targets[@]}"; do
    [ -e "$target" ] && rm -rf "$target"
  done

  # 3. 环境变量设置
  export BISON_LOCALEDIR=${BISON_LOCALEDIR:-/usr/share/locale}
  export GETTEXT_PREFIX=${GETTEXT_PREFIX:-/usr}
  export LIBINTL=${LIBINTL:-1}
  export PATH="${WRT_DIR}/staging_dir/host/bin:$PATH"

  # 4. 编译关键包（带资源监控）
  status "开始编译关键包 ..."
  critical_packages=(
    "package/libs/gettext-full/host"
    "package/devel/gperf/host"
  )
  
  for pkg in "${critical_packages[@]}"; do
    local pkg_name=$(basename "$pkg")
    local log_file="${LOG_DIR}/${pkg_name}.log"
    
    mkdir -p "$(dirname "$log_file")"
    [ -f "$log_file" ] && mv "$log_file" "${log_file}.old"
    
    status "编译: $pkg_name (并行度: ${MAX_JOBS})"
    status "详细日志: ${log_file}"
    
    # 启动日志追踪
    local tail_pid=$(tail_log "$log_file" "$pkg_name")
    
    # 执行编译
    set +e
    compile_with_monitor "$pkg" "$log_file" "$MAX_JOBS"
    local exit_code=$?
    set -e
    
    # 停止日志追踪
    kill $tail_pid 2>/dev/null || true
    
    if [ $exit_code -eq 0 ]; then
      log "$pkg_name 编译成功"
      # 显示编译时间
      echo "编译时间: $(grep real "$log_file" | tail -1)"
    else
      show_error_summary "$log_file"
      die "$pkg_name 编译失败！请查看完整日志: ${log_file}"
    fi
  done

  # 5. 完成提示
  log ">>> host 依赖修复全部完成！"
  log "编译日志已保存到: ${LOG_DIR}"
  
  # 显示资源使用报告
  echo -e "\n${CYAN}======= 最终资源使用报告 =======${NC}"
  grep "系统负载" ${LOG_DIR}/*.monitor | tail -n 5
  echo -e "${CYAN}================================${NC}"
}

# 执行主程序
main
