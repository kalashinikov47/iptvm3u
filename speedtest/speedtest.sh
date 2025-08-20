#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}


countdown(){

 for i in $(seq $1 -1 1)
 do
	echo -n $i;sleep 1;echo -ne "\r     \r"

 done

}

node_now=$(cat /etc/config/shadowsocksr |grep global_server|sed -e 's/\toption global_server //'  -e  "s/'cfg0//" -e "s/4a8f'//")

case $node_now in 
6)
yellow "\n当前节点:hostdare"
node_string="hostdare"
;;
7)
yellow  "\n当前节点:vultr"
node_string="vultr"
;;
8)
yellow  "\n当前节点:ocp"
node_string="ocp"
;;
9)
yellow  "\n当前节点:aws"
node_string="aws"
;;
*)
yellow "\n当前节点:其他"
node_string="other"
;;
esac


green "-------------------------------------------"

echo "  1、仅测速"
echo "  7、vultr"
echo "  6、hostdae"
echo "  8、ocp"
echo "  9、aws"
echo "  0、测速并替换"
echo  "  10秒后默认选择[0、测速并替换]"
green "-------------------------------------------"

read  -t 10 -p "请设置使用的代理:" node_assign
node_assign=${node_assign:-0}

case $node_assign in 
	7)
		green '已选择'$node_assign
		echo "设置节点"
		sed  -i  's/cfg..4a8f/cfg074a8f/'  /etc/config/shadowsocksr
		/etc/init.d/shadowsocksr restart
		echo "设置完成"
	;;
	#hostdare
	6)
		green '已选择'$node_assign
		echo "设置节点"

		sed  -i  's/cfg..4a8f/cfg064a8f/'  /etc/config/shadowsocksr
		/etc/init.d/shadowsocksr restart
		echo "设置完成"
	;;
	# ocp
	8)
		green '已选择'$node_assign
		echo "设置节点"

		sed  -i  's/cfg..4a8f/cfg084a8f/'  /etc/config/shadowsocksr
		/etc/init.d/shadowsocksr restart
		echo "设置完成"
	;;
	#aws
	9)
		green '已选择'$node_assign
		echo "设置节点"

		sed  -i  's/cfg..4a8f/cfg094a8f/'  /etc/config/shadowsocksr
		/etc/init.d/shadowsocksr restart
		echo "设置完成"
	;;
	0)
		green  "\n第一次测速并替换，请耐心等待15秒："
		curl https://speedtest.anycast.eu.org/500MB.swf -o /dev/null >log.txt --max-time 15 2>&1 &
		countdown 15
		aa1=$(cat log.txt |tr '\r' '\n' | awk '{print $NF}'| sed '$d'|tail -n 1)
		aa=$(cat log.txt |tr '\r' '\n' | awk '{print $NF}'| sed '$d'|tail -n 1|sed 's/k//g')
		# echo -e $node_string '\t\t' $(date +%D)'  '$(date +%T) '\t' $aa '\t定时测速' >>speedtest.log
		printf "| %-15s|  %-10s %-10s|%8s  |%20s  |\n" $node_string $(date +%D) $(date +%T) $aa1 '定时测速'>>speedtest.log
		echo -e $node_string $(date +%D)'  '$(date +%T)'\t'$aa1 
		if  [ $aa -gt 1500 ] && [ aa != aa1 ]
		then
			 yellow "本节点速度还可以，无需更换"
			 
		else

			green  "第2次测速并替换，请耐心等待15秒："
               		curl https://speedtest.anycast.eu.org/500MB.swf -o /dev/null >log.txt --max-time 15 2>&1 &
                	countdown 15
                	aa1=$(cat log.txt |tr '\r' '\n' | awk '{print $NF}'| sed '$d'|tail -n 1)
                	aa=$(cat log.txt |tr '\r' '\n' | awk '{print $NF}'| sed '$d'|tail -n 1|sed 's/k//g')
                	# echo -e $node_string '\t\t' $(date +%D)'  '$(date +%T) '\t' $aa '\t定时测速' >>speedtest.log
               		printf "| %-15s|  %-10s %-10s|%8s  |%20s  |\n" $node_string $(date +%D) $(date +%T) $aa1 '定时测速'>>speedtest.log
               		echo -e $node_string $(date +%D)'  '$(date +%T)'\t'$aa1

			if  [ $aa -lt 1500 ] || [ aa1 = aa ]
			then

				sed  -i  's/cfg..4a8f/cfg064a8f/'  /etc/config/shadowsocksr
				/etc/init.d/shadowsocksr restart
				yellow "更换为hostdare节点" >>speedtest.log
				yellow "更换为hostdare节点" 
                       		curl -o /dev/null --data "token=24fa5acaf19d4cce84298df83c3f3dc2&title=节点更换通知&content=730弄节点更换为hostdare"  http://pushplus.hxtrip.com/send
        		
		
                	fi
		fi

	;;
	1)
		
		yellow "\n启动测速，请耐心等待15秒"
		curl https://speedtest.anycast.eu.org/500MB.swf -o /dev/null >log.txt --max-time 15 2>&1 &
		countdown 15
		aa1=$(cat log.txt |tr '\r' '\n' | awk '{print $NF}'| sed '$d'|tail -n 1)
		aa=$(cat log.txt |tr '\r' '\n' | awk '{print $NF}'| sed '$d'|tail -n 1|sed 's/k//g')
                # echo -e $node_string '\t\t' $(date +%D)'  '$(date +%T) '\t' $aa '\t手动测速' >>speedtest.log
		printf "| %-15s|  %-10s %-10s|%8s  |%20s  |\n" $node_string $(date +%D) $(date +%T) $aa1 '手动测速'>>speedtest.log
		echo -e $node_string $(date +%D)'  '$(date +%T)'\t'$aa1
		;;
	*)
		yellow "无效输入，退出"

		;;
esac

