#!/usr/bin/env bash

# 配置参数 - 降低要求，提高成功率
MAX_RETRIES=${MAX_RETRIES:-2}           # 最大重试次数
STREAM_DURATION=${STREAM_DURATION:-8}    # 拉流时长（秒）- 从10秒降到8秒
FFMPEG_TIMEOUT=${FFMPEG_TIMEOUT:-15}     # ffmpeg 总超时 - 从20秒降到15秒
CONNECT_TIMEOUT=${CONNECT_TIMEOUT:-3}    # 连接超时（秒）
FRAMES_THRESHOLD=${FRAMES_THRESHOLD:-300} # 帧数阈值 - 从400降到300
THRESHOLD_MBPS=${THRESHOLD_MBPS:-3}      # 速度阈值 - 从5降到3 Mb/s

# 用法检查
if [ "$#" -ne 2 ]; then
  echo "用法: $0 <ip:port> <stream>" >&2
  echo "0 Mb/s"
  exit 1
fi

# 构造 IPTV 地址
URL="http://$1/$2"

# 日志函数（输出到 stderr，避免污染结果）
log_debug() {
  [ "${DEBUG:-0}" = "1" ] && echo "[$(date +%H:%M:%S)] $*" >&2
}

# 测速函数
test_stream() {
  local url="$1"
  
  # 临时输出文件
  local output_file=$(mktemp -p "${TMPDIR:-/tmp}" speedtest_XXXXXX.mp4)
  trap 'rm -f "$output_file" 2>/dev/null' RETURN
  
  log_debug "测试: $url"
  
  # 计时开始
  local start_time=$(date +%s)
  
  # 拉流测试 - 添加更多超时保护
  if timeout ${FFMPEG_TIMEOUT}s ffmpeg \
      -loglevel error \
      -nostdin \
      -timeout $((CONNECT_TIMEOUT * 1000000)) \
      -y \
      -i "$url" \
      -t ${STREAM_DURATION} \
      -c copy \
      "$output_file" >/dev/null 2>&1; then
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 检查时长
    if [ "$duration" -le 0 ]; then
      log_debug "无效时长"
      return 1
    fi
    
    # 检查文件大小
    local file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
    if [ "$file_size" -le 10000 ]; then  # 至少10KB
      log_debug "文件太小: ${file_size}B"
      return 1
    fi
    
    # 检查帧数
    local frames=$(ffprobe -v error -select_streams v:0 -count_packets \
      -show_entries stream=nb_read_packets -of csv=p=0 "$output_file" 2>/dev/null || echo "0")
    
    if [ "$frames" -lt "$FRAMES_THRESHOLD" ]; then
      log_debug "帧数不足: $frames < $FRAMES_THRESHOLD"
      return 1
    fi
    
    # 计算速度
    local speed=$(echo "scale=2; $file_size * 8 / $duration / 1000000" | bc 2>/dev/null || echo "0")
    
    # 检查速度阈值
    if [ "$(echo "$speed < $THRESHOLD_MBPS" | bc 2>/dev/null || echo 1)" = "1" ]; then
      log_debug "速度过低: ${speed}Mb/s"
      return 1
    fi
    
    log_debug "成功: ${speed}Mb/s (${frames}帧, ${file_size}B, ${duration}s)"
    echo "$speed"
    return 0
  else
    log_debug "ffmpeg失败"
    return 1
  fi
}

# 带重试的主逻辑
for retry in $(seq 0 $MAX_RETRIES); do
  if [ $retry -gt 0 ]; then
    log_debug "重试 $retry/$MAX_RETRIES"
    sleep 1
  fi
  
  if result=$(test_stream "$URL"); then
    echo "$result Mb/s"
    exit 0
  fi
done

# 所有尝试失败
echo "0 Mb/s"
exit 0
