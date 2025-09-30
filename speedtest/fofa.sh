#!/bin/bash

# ============================================================================
# 优化版 FOFA 搜索和测速脚本
# 主要改进：
# 1. 添加 FOFA 请求重试机制和超时控制
# 2. 优化端口连通性测试（增加超时）
# 3. 限制测试 IP 数量，提高效率
# 4. 改进空结果处理，避免脚本失败
# 5. 添加详细日志输出
# ============================================================================

# 配置参数
MAX_FOFA_RETRIES=3        # FOFA 请求最大重试次数
FOFA_TIMEOUT=15           # FOFA 请求超时（秒）
NC_TIMEOUT=2              # netcat 连接超时（秒）
MAX_TEST_IPS=25           # 最大测试 IP 数量 - 避免测试过多 IP
MIN_VALID_IPS=1           # 最少需要的有效 IP 数量
CITY_DELAY_MIN=3          # 城市间最小延迟（秒）- 防止 FOFA 限流
CITY_DELAY_MAX=8          # 城市间最大延迟（秒）- 防止 FOFA 限流

# 原有变量定义
time=$(date +%m%d%H%M)
i=0

if [ $# -eq 0 ]; then
  echo "请选择城市："
  echo "1. 上海电信（Shanghai_103）"
  echo "2. 北京联通（Beijing_liantong_145）"
  echo "3. 四川电信（Sichuan_333）"
  echo "4. 浙江电信（Zhejiang_120）"
  echo "5. 北京电信（Beijing_dianxin_186）"
  echo "6. 江苏（Jiangsu）"
  echo "7. 广东电信（Guangdong_332）"
  echo "8. 河南电信（Henan_327）"
  echo "9. 山西电信（Shanxi_117）"
  echo "10. 天津联通（Tianjin_160）"
  echo "11. 湖北电信（Hubei_90）"
  echo "12. 福建电信（Fujian_114）"
  echo "13. 湖南电信（Hunan_282）"
  echo "14. 甘肃电信（Gansu_105）"
  echo "15. 河北联通（Hebei_313）"
  echo "16. 浙江联通（Zhejiang_121）"
  echo "0. 全部"
  read -t 10 -p "输入选择或在10秒内无输入将默认选择全部: " city_choice

  if [ -z "$city_choice" ]; then
      echo "未检测到输入，自动选择全部选项..."
      city_choice=0
  fi
else
  city_choice=$1
fi

# 城市列表（用于选项0）
declare -a all_cities=(1 2 3 4 6 7 8 9 10 11 12 13 14 15 16)

# 处理单个城市的函数
process_city() {
  local choice=$1
  
  # 根据选择设置城市和相应的stream
  case $choice in
    1)
        city="Shanghai_103"
        stream="udp/239.45.1.4:5140"
        channel_key="上海"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Shanghai" && asn="4812" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    2)
        city="Beijing_liantong_145"
        stream="rtp/239.3.1.236:2000"
        channel_key="北京联通"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Beijing" && asn="4808" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    3)
        city="Sichuan_333"
        stream="udp/239.93.0.169:5140"
        channel_key="四川电信"        
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Sichuan" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    4)
        city="Zhejiang_120"
        stream="rtp/233.50.201.63:5140"
        channel_key="浙江电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Zhejiang" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    5)
        city="Beijing_dianxin_186"
        stream="udp/225.1.8.80:2000"
        channel_key="北京电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Beijing" && asn="4847" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    6)
        city="Jiangsu"
        stream="rtp/239.49.8.132:6000"        
        channel_key="江苏"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Jiangsu" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    7)
        city="Guangdong_332"
        stream="udp/239.77.1.98:5146"
        channel_key="广东电信"        
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Guangdong" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    8)
        city="Henan_327"        
        stream="rtp/239.16.20.1:10010"
        channel_key="河南电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Henan" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    9)
        city="Shanxi_117"
        stream="rtp/226.0.2.69:9136"
        channel_key="山西电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Shanxi" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    10)
        city="Tianjin_160"
        stream="udp/225.1.1.112:5002"
        channel_key="天津联通"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Tianjin" && asn="4837" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    11)
        city="Hubei_90"
        stream="rtp/239.69.1.68:9694"
        channel_key="湖北电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Hubei" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    12)
        city="Fujian_114"
        stream="rtp/239.61.2.155:9022"
        channel_key="福建电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Fujian" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    13)
        city="Hunan_282"
        stream="udp/239.76.253.100:9000"
        channel_key="湖南电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Hunan" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    14)
        city="Gansu_105"
        stream="rtp/239.255.30.250:8231"
        channel_key="甘肃电信"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Gansu" && asn="4134" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    15)
        city="Hebei_313"
        stream="rtp/239.253.92.83:8012"
        channel_key="河北联通"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Hebei" && asn="4837" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    16)
        city="Zhejiang_121"
        stream="rtp/233.50.200.102:5140"
        channel_key="浙江联通"
        url_fofa=$(echo  '"udpxy" && country="CN" && region="Zhejiang" && asn="4837" && protocol="http"' | base64 |tr -d '\n')
        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        ;;
    *)
        echo "无效选择: $choice"
        return 1
        ;;
  esac

  echo ""
  echo "======================================================================="
  echo "开始处理: ${channel_key} (${city})"
  echo "======================================================================="

  ipfile="ip/${city}.ip"
  only_good_ip="ip/${city}.onlygood.ip"
  rm -f $only_good_ip
  mkdir -p ip result txt
  
  # FOFA 搜索（带重试）
  echo "==> 步骤1: 从 FOFA 检索 IP"
  fofa_success=false
  for retry in $(seq 1 $MAX_FOFA_RETRIES); do
    echo "    尝试 $retry/$MAX_FOFA_RETRIES"
    
    if timeout ${FOFA_TIMEOUT}s curl -sSL \
        --connect-timeout 10 \
        --max-time ${FOFA_TIMEOUT} \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        -o "test_${city}.html" \
        "$url_fofa" 2>/dev/null; then
      
      # 检查文件是否有内容
      if [ -s "test_${city}.html" ] && grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' "test_${city}.html"; then
        echo "    ✓ FOFA 搜索成功"
        fofa_success=true
        break
      else
        echo "    ✗ FOFA 返回空结果"
      fi
    else
      echo "    ✗ FOFA 请求失败"
    fi
    
    [ $retry -lt $MAX_FOFA_RETRIES ] && sleep 2
  done
  
  if [ "$fofa_success" = false ]; then
    echo "警告：${city} FOFA 搜索失败，生成空结果文件"
    touch "result/result_fofa_${city}.txt"
    touch "txt/fofa_${city}.txt"
    rm -f "test_${city}.html"
    return 0
  fi
  
  # 提取 IP
  grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$' "test_${city}.html" | \
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' | \
    head -n 100 > "$ipfile"
  rm -f "test_${city}.html"
  
  # 检查是否获取到 IP
  if [ ! -s "$ipfile" ]; then
    echo "警告：${city} 未获取到任何 IP，生成空结果文件"
    touch "result/result_fofa_${city}.txt"
    touch "txt/fofa_${city}.txt"
    return 0
  fi
  
  ip_count=$(wc -l < "$ipfile")
  echo "    获取到 $ip_count 个候选 IP"
  
  # 端口连通性测试
  echo "==> 步骤2: 端口连通性测试"
  tested=0
  success=0
  
  while IFS= read -r ip; do
    ((tested++))
    tmp_ip=$(echo -n "$ip" | sed 's/:/ /')
    
    if timeout ${NC_TIMEOUT}s nc -w ${NC_TIMEOUT} -z $tmp_ip 2>&1 | grep -q "succeeded"; then
      echo "$ip" >> "$only_good_ip"
      ((success++))
      echo "    [$tested/$ip_count] ✓ $ip"
    else
      echo "    [$tested/$ip_count] ✗ $ip"
    fi
  done < "$ipfile"
  
  echo "    连通性测试完成: $success/$tested 可用"
  
  # 检查是否有可用 IP
  if [ ! -f "$only_good_ip" ] || [ ! -s "$only_good_ip" ]; then
    echo "警告：${city} 无可用 IP，生成空结果文件"
    touch "result/result_fofa_${city}.txt"
    touch "txt/fofa_${city}.txt"
    return 0
  fi
  
  lines=$(wc -l < "$only_good_ip")
  
  # 限制测试数量
  if [ "$lines" -gt "$MAX_TEST_IPS" ]; then
    echo "    限制测试前 $MAX_TEST_IPS 个 IP"
    head -n $MAX_TEST_IPS "$only_good_ip" > "${only_good_ip}.tmp"
    mv "${only_good_ip}.tmp" "$only_good_ip"
    lines=$MAX_TEST_IPS
  fi
  
  # 速度测试
  echo "==> 步骤3: 速度测试 ($lines 个 IP)"
  line_i=0
  valid_count=0
  mkdir -p tmpip
  
  while read -r line; do
    ip=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')
    
    if [ -n "$ip" ]; then
      echo "$ip" > "tmpip/ip_$line_i.txt"
      ((line_i++))
    fi
  done < "$only_good_ip"
  
  line_i=0
  for temp_file in tmpip/ip_*.txt; do
    [ ! -f "$temp_file" ] && continue
    
    ((line_i++))
    ip=$(<"$temp_file")
    
    # 验证 ip 和 stream 都不为空
    if [ -z "$ip" ] || [ -z "$stream" ]; then
      echo "    [$line_i/$lines] 跳过 (参数无效)"
      continue
    fi
    
    echo -n "    [$line_i/$lines] 测试 $ip ... "
    a=$(./speed.sh "$ip" "$stream" 2>/dev/null || echo "0 Mb/s")
    
    # 只记录有效结果
    if [[ "$a" != "0 Mb/s" ]] && [[ "$a" != "0.00 Mb/s" ]]; then
      echo "$ip $a" >> "speedtest_${city}_$time.log"
      ((valid_count++))
      echo "✓ $a"
    else
      echo "✗ 无效"
    fi
  done
  
  rm -rf tmpip/*
  echo "    速度测试完成: $valid_count/$lines 有效"
  
  # 生成结果文件
  echo "==> 步骤4: 生成结果文件"
  
  # 如果没有有效结果，创建空文件
  if [ ! -f "speedtest_${city}_$time.log" ]; then
    touch "result/result_fofa_${city}.txt"
    touch "txt/fofa_${city}.txt"
    echo "    警告: 无有效测速结果"
    return 0
  fi
  
  awk '/M|k/{print $2"  "$1}' "speedtest_${city}_$time.log" | sort -n -r > "result/result_fofa_${city}.txt"
  
  # 显示结果
  if [ -s "result/result_fofa_${city}.txt" ]; then
    echo "    前3名:"
    head -n 3 "result/result_fofa_${city}.txt" | nl
  fi
  
  ip1=$(awk 'NR==1{print $2}' result/result_fofa_${city}.txt)
  ip2=$(awk 'NR==2{print $2}' result/result_fofa_${city}.txt)
  ip3=$(awk 'NR==3{print $2}' result/result_fofa_${city}.txt)
  rm -f "speedtest_${city}_$time.log"
  
  # 用 3 个最快 ip 生成对应城市的 txt 文件
  program="template/template_${city}.txt"
  
  if [ ! -f "$program" ]; then
    echo "    警告: 模板文件不存在: $program"
    touch "txt/fofa_${city}.txt"
    return 0
  fi
  
  sed "s/ipipip/$ip1/g" "$program" > tmp1.txt
  sed "s/ipipip/$ip2/g" "$program" > tmp2.txt
  sed "s/ipipip/$ip3/g" "$program" > tmp3.txt
  cat tmp1.txt tmp2.txt tmp3.txt > "txt/fofa_${city}.txt"
  rm -rf tmp1.txt tmp2.txt tmp3.txt
  
  echo "    ✓ 完成"
}

# 主逻辑
if [ "$city_choice" = "0" ]; then
  echo "将处理所有16个城市，这可能需要较长时间..."
  echo "注意：城市间会有 ${CITY_DELAY_MIN}-${CITY_DELAY_MAX} 秒延迟，以防止 FOFA 限流"
  
  city_index=0
  total_cities=${#all_cities[@]}
  
  for choice in "${all_cities[@]}"; do
    ((city_index++))
    echo ""
    echo ">>> 正在处理第 $city_index/$total_cities 个城市"
    
    process_city $choice || echo "城市 $choice 处理失败，继续下一个"
    
    # 在处理完一个城市后，添加随机延迟（最后一个城市除外）
    if [ $city_index -lt $total_cities ]; then
      # 生成随机延迟时间
      delay=$((CITY_DELAY_MIN + RANDOM % (CITY_DELAY_MAX - CITY_DELAY_MIN + 1)))
      echo ""
      echo "⏳ 等待 ${delay} 秒后继续处理下一个城市（防止 FOFA 限流）..."
      sleep $delay
    fi
  done
else
  process_city $city_choice
fi

# 合并所有城市的txt文件
echo ""
echo "======================================================================="
echo "合并所有城市结果到 zubo_fofa.txt"
echo "======================================================================="

echo "上海电信,#genre#" > zubo_fofa.txt
cat txt/fofa_Shanghai_103.txt >> zubo_fofa.txt 2>/dev/null || true

echo "江苏,#genre#" >> zubo_fofa.txt
cat txt/fofa_Jiangsu.txt >> zubo_fofa.txt 2>/dev/null || true

echo "北京联通,#genre#" >> zubo_fofa.txt
cat txt/fofa_Beijing_liantong_145.txt >> zubo_fofa.txt 2>/dev/null || true

echo "天津联通,#genre#" >> zubo_fofa.txt
cat txt/fofa_Tianjin_160.txt >> zubo_fofa.txt 2>/dev/null || true

echo "河南电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Henan_327.txt >> zubo_fofa.txt 2>/dev/null || true

echo "山西电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Shanxi_117.txt >> zubo_fofa.txt 2>/dev/null || true

echo "广东电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Guangdong_332.txt >> zubo_fofa.txt 2>/dev/null || true

echo "四川电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Sichuan_333.txt >> zubo_fofa.txt 2>/dev/null || true

echo "浙江电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Zhejiang_120.txt >> zubo_fofa.txt 2>/dev/null || true

echo "湖北电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Hubei_90.txt >> zubo_fofa.txt 2>/dev/null || true

echo "福建电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Fujian_114.txt >> zubo_fofa.txt 2>/dev/null || true

echo "湖南电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Hunan_282.txt >> zubo_fofa.txt 2>/dev/null || true

echo "甘肃电信,#genre#" >> zubo_fofa.txt
cat txt/fofa_Gansu_105.txt >> zubo_fofa.txt 2>/dev/null || true

echo "河北联通,#genre#" >> zubo_fofa.txt
cat txt/fofa_Hebei_313.txt >> zubo_fofa.txt 2>/dev/null || true

echo "浙江联通,#genre#" >> zubo_fofa.txt
cat txt/fofa_Zhejiang_121.txt >> zubo_fofa.txt 2>/dev/null || true

echo "✓ 合并完成！生成文件: zubo_fofa.txt"
echo ""
