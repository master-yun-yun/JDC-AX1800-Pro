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

# --------------------deepseek优化版本---------------------------- #

#!/usr/bin/env bash
# fix_gettext_full.sh - 修复 OpenWRT host 依赖构建问题（实时日志输出版）

set -euo pipefail

# ================= 配置区域 =================
MAX_JOBS=${MAX_JOBS:-1}                      # 默认串行编译
TOOLCHAIN_JOBS=${TOOLCHAIN_JOBS:-1}          # 工具链编译使用串行
LOG_DIR="${LOG_DIR:-logs}"                    # 日志存储目录
ERROR_SUMMARY_LINES=30                       # 错误摘要显示行数
DOWNLOAD_TIMEOUT=300                         # 下载超时5分钟
MIN_DISK_SPACE=10000000                      # 最小磁盘空间 10GB
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

# 磁盘空间检查
check_disk_space() {
  local avail=$(df -k . | awk 'NR==2 {print $4}')
  
  if [ "$avail" -lt $MIN_DISK_SPACE ]; then
    die "磁盘空间不足! 可用: $(($avail/1024))MB, 需要至少 $(($MIN_DISK_SPACE/1024))MB"
  fi
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

# 带实时日志输出的编译函数
compile_with_realtime_log() {
  local target=$1
  local log_file="${LOG_DIR}/${target//\//_}.log"
  local job_count=${2:-1}
  
  mkdir -p "$(dirname "$log_file")"
  [ -f "$log_file" ] && mv "$log_file" "${log_file}.old"
  
  status "编译 $target (并行度: ${job_count})"
  status "实时日志输出已启用"
  
  # 执行编译并实时输出日志
  set +e
  echo -e "${CYAN}==== 开始编译 $target ====${NC}"
  time make $target -j${job_count} V=s 2>&1 | tee "$log_file"
  local exit_code=${PIPESTATUS[0]}
  set -e
  
  if [ $exit_code -eq 0 ]; then
    log "$target 编译成功"
    return 0
  else
    show_error_summary "$log_file"
    die "$target 编译失败！请查看完整日志: ${log_file}"
  fi
}

# 带实时输出的关键包编译
compile_critical_package() {
  local pkg_path=$1
  local pkg_name=$(basename "$pkg_path")
  local log_file="${LOG_DIR}/${pkg_name}.log"
  
  mkdir -p "$(dirname "$log_file")"
  [ -f "$log_file" ] && mv "$log_file" "${log_file}.old"
  
  status "编译: $pkg_name (并行度: ${MAX_JOBS})"
  
  # 清理旧文件
  make "$pkg_path/clean" >/dev/null 2>&1 || true
  
  # 执行编译并实时输出日志
  set +e
  echo -e "${CYAN}==== 开始编译 $pkg_name ====${NC}"
  time make "$pkg_path/compile" -j${MAX_JOBS} V=s 2>&1 | tee "$log_file"
  local exit_code=${PIPESTATUS[0]}
  set -e
  
  if [ $exit_code -eq 0 ]; then
    log "$pkg_name 编译成功"
    return 0
  else
    show_error_summary "$log_file"
    die "$pkg_name 编译失败！请查看完整日志: ${log_file}"
  fi
}

# ============== 主程序 ==============
main() {
  # 基础检查
  : ${WRT_DIR:="$(cd "$(dirname "$0")/../wrt" && pwd)"}
  cd "${WRT_DIR}" || die "无法进入目录: ${WRT_DIR}"
  [ -f Makefile ] || die "未在 wrt 根目录发现 Makefile"
  
  # 磁盘空间检查
  check_disk_space
  
  # 创建日志目录
  LOG_DIR="${WRT_DIR}/${LOG_DIR}"
  mkdir -p "$LOG_DIR"
  
  # 显示系统信息
  log "系统信息: $(uname -a)"
  log "处理器: $(nproc) 核心"
  log "内存: $(free -h | awk '/Mem:/{print $2}')"
  log "磁盘空间: $(df -h . | awk 'NR==2 {print $4 " free"}')"
  status "工具链并行度: ${TOOLCHAIN_JOBS}"
  status "最大并行任务数: ${MAX_JOBS}"
  status "日志目录: ${LOG_DIR}"

  # 0. 生成 .config
  if [ ! -f .config ]; then
    status "生成默认 .config ..."
    make defconfig | tee "${LOG_DIR}/defconfig.log"
  fi

  # 下载所有依赖源码
  status "下载所有依赖源码 (超时: ${DOWNLOAD_TIMEOUT}s) ..."
  set +e
  timeout $DOWNLOAD_TIMEOUT make download | tee "${LOG_DIR}/download.log"
  local download_status=${PIPESTATUS[0]}
  set -e
  
  if [ $download_status -eq 124 ]; then
    warn "下载超时，尝试继续编译"
  elif [ $download_status -ne 0 ]; then
    warn "下载失败 (状态码: $download_status)，尝试继续编译"
  else
    log "依赖源码下载成功"
  fi

  # 1. 预编译 host 工具链（串行）
  status "预编译 host 工具链 (使用串行编译)"
  compile_with_realtime_log "tools/install" "$TOOLCHAIN_JOBS"
  compile_with_realtime_log "toolchain/install" "$TOOLCHAIN_JOBS"

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

  # 4. 编译关键包（实时日志输出）
  status "开始编译关键包 ..."
  critical_packages=(
    "package/libs/gettext-full/host"
    "package/devel/gperf/host"
  )
  
  for pkg in "${critical_packages[@]}"; do
    compile_critical_package "$pkg"
  done

  # 5. 完成提示
  log ">>> host 依赖修复全部完成！"
  log "编译日志已保存到: ${LOG_DIR}"
}

# 执行主程序
main
