#!/usr/bin/env bash

# 目前有3台服务器，提供了brook server端，客户端只需要选择其中一个即可
declare -A server1=(["vendor"]="请填入服务商名称" ["ip"]="请填入服务器IP" ["port"]="请填入端口" ["password"]="请填入密码" ["description"]="请填入描述")
declare -A server2=(["vendor"]="请填入服务商名称" ["ip"]="请填入服务器IP" ["port"]="请填入端口" ["password"]="请填入密码" ["description"]="请填入描述")
declare -A server3=(["vendor"]="请填入服务商名称" ["ip"]="请填入服务器IP" ["port"]="请填入端口" ["password"]="请填入密码" ["description"]="请填入描述")

servers=("server1" "server2" "server3")

print_server_info() {
	local order=$1
	local vendor=$2
	local ip=$3
	local port=$4
	local desc=$5
	echo -e "\e[1;32m$order\e[0m. from \e[1;31m$vendor\e[0m: \e[1;36m$ip\e[0m:\e[1;36m$port\e[0m $desc"
}

echo "选择一个目标服务器"
for ((i = 0; i < ${#servers[@]}; i++)); do
	declare -n server=${servers[i]}
	print_server_info $((i + 1)) "${server[vendor]}" "${server[ip]}" "${server[port]}" "${server[description]}"
done

echo
for i in 5 4 3 2 1; do
	echo -ne "\rchoose one, input it's index (default 1, auto in ${i}s): "
	read -t 1 choice
	if [ $? -eq 0 ]; then
		break
	fi
done
echo
choice=${choice:-1}

if [[ $choice -lt 1 || $choice -gt ${#servers[@]} ]]; then
	echo "invalid, return"
	exit 1
fi

declare -n server=${servers[$((choice - 1))]}
brook client -s "${server[ip]}":"${server[port]}" -p "${server[password]}" --socks5 0.0.0.0:9998 &
sleep 2
brook socks5tohttp -s 127.0.0.1:9998 -l 0.0.0.0:8118 &
