#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# 用法检查
if [ "$#" -ne 2 ]; then
  echo "用法: $0 <ip:port> <stream>"
  exit 1
fi

# 构造 IPTV 地址
URL="http://$1/$2"

# 临时输出文件（放到 /tmp，避免仓库变脏）
OUTPUT_FILE=$(mktemp -p "${TMPDIR:-/tmp}" speedtest_video_XXXXXX.mp4)
trap 'rm -f "$OUTPUT_FILE" >/dev/null 2>&1 || true' EXIT

# 计时开始
START_TIME=$(date +%s)

# 限时拉流并保存 10 秒，出错静默
# -loglevel error: 仅错误输出；-nostdin: 非交互；-rw_timeout 5s（以微秒表示）
if ! timeout 20s ffmpeg -loglevel error -nostdin -rw_timeout 5000000 -y -i "$URL" -t 10 -c copy "$OUTPUT_FILE" >/dev/null 2>&1; then
  echo "0"
  exit 0
fi

# 计时结束
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# 防止除零
if [ "$DURATION" -le 0 ]; then
  echo "0"
  exit 0
fi

# 文件大小（字节）- 兼容性更好的获取方式
FILE_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d '[:space:]')
if [ -z "$FILE_SIZE" ] || [ "$FILE_SIZE" -le 0 ]; then
  echo "0"
  exit 0
fi

# 可选：按视频帧数过滤，排除几秒就断流的节点（默认阈值 400，可通过 FRAMES_THRESHOLD 覆盖）
FRAMES_THRESHOLD=${FRAMES_THRESHOLD:-400}
FRAMES=$(ffprobe -v error -select_streams v:0 -count_packets \
  -show_entries stream=nb_read_packets -of csv=p=0 "$OUTPUT_FILE" 2>/dev/null || echo "")
FRAMES=${FRAMES:-0}
if [ "$FRAMES" -lt "$FRAMES_THRESHOLD" ]; then
  echo "0"
  exit 0
fi

# 计算下载速度（字节/秒 → Mb/s）
DOWNLOAD_SPEED=$(echo "scale=4; $FILE_SIZE / $DURATION" | bc)
DOWNLOAD_SPEED_MBPS=$(echo "scale=2; $DOWNLOAD_SPEED * 8 / 1000000" | bc)

# 低速阈值（默认 5 Mb/s，可通过 THRESHOLD_MBPS 覆盖）
THRESHOLD_MBPS=${THRESHOLD_MBPS:-5}
if (( $(echo "$DOWNLOAD_SPEED_MBPS < $THRESHOLD_MBPS" | bc -l) )); then
  DOWNLOAD_SPEED_MBPS=0
fi

# 输出（保持与上游脚本匹配的格式，便于 grep/awk 过滤）
echo "$DOWNLOAD_SPEED_MBPS Mb/s"
