#!/bin/bash

# Docker 网络相关
NET_NAME=fisco
NET_SUB=10.10.10.0/24

# 镜像相关
IMG_NAME=fisco-dev
IMG_TAG=latest

# 实例相关
INSTANCE_PREFIX=instance
INSTANCE_NUM=

function LOG_ERROR() {
    content=${1}
    echo -e "\033[31m${content}\033[0m"
}

function LOG_INFO() {
    content=${1}
    echo -e "\033[32m${content}\033[0m"
}

# 权限检查
function sudo_permission_check() {
    if ! sudo echo -n " "; then
        echo "no sudo permission, please add yourself in the sudoers"
        exit 1
    fi
}

# 创建网络
# 根据 NET_NAME 和 NET_SUB 参数创建网络
function create_docker_network() {
    # 检查网络是否存在
    local p_name=$(sudo docker network ls --format '{{json .Name}}' | grep -E "^\"${NET_NAME}\"$")
    if [[ -n $p_name ]]; then
        LOG_INFO "网络:${NET_NAME}已存在"
        return
    fi

    sudo docker network create -d bridge ${NET_NAME} --subnet ${NET_SUB} --internal 2>&1 >/dev/null
    if [[ $? -ne 0 ]]; then
        LOG_ERROR "网络：${NET_NAME} 创建失败"
        exit 1
    fi
}

# 构建镜像
function build_image() {

    # 检查镜像是否存在
    sudo docker images --format '{{json .Repository}}:{{json .Tag}}' | grep -E "^\"${IMG_NAME}\":\"${IMG_TAG}\"$" 2>&1 >/dev/null
    if [[ $? -eq 0 ]]; then
        LOG_INFO "镜像：镜像存在，正在检查是否构建..."
        # 检查是否需要构建
        cmp_time_stat
        local last_status=$?
        if [[ $last_status -ne 0 ]]; then
            LOG_INFO "镜像：镜像为最新，无需构建"
            return
        else
            LOG_INFO "镜像：已更新"
        fi

        docker ps --format '{{json .Image}}' | grep "${IMG_NAME}:${IMG_TAG}" 2>&1 >/dev/null
        if [[ $? -eq 0 ]]; then
            LOG_ERROR "容器：${IMG_NAME}:${IMG_TAG} 镜像已绑定容器，请删除"
            exit 1
        fi

        # 清理镜像文件
        sudo docker image rm ${IMG_NAME}:${IMG_TAG} 2>&1 >/dev/null
        if [[ $? -ne 0 ]]; then
            LOG_ERROR "镜像：旧镜像清理失败，请排查原因"
            exit 1
        fi
    else
        LOG_INFO "镜像: ${IMG_NAME} 不存在，开始构建..."
    fi

    sudo docker build -t ${IMG_NAME} ./build/ 2>&1 >/dev/null
    if [[ $? -ne 0 ]]; then
        LOG_ERROR "镜像：${IMG_NAME}构建失败请排查原因"
        exit 1
    fi

    LOG_INFO "镜像：${IMG_NAME} 构建完成"
}

# 解析参数，调用时传入 $@
# 默认： parse_argus $@
function parse_argus() {
    # 检测实例数
    if [[ $1 =~ ^[0-9]+$ && -n $2 ]]; then
        INSTANCE_NUM=$1
        INSTANCE_PREFIX=$2
        return
    fi

    LOG_ERROR "参数错误: ./run.sh 参数个数 实例前缀"
    exit 1
}

# 根据 INSTANCE_NUM 变量的值创建实例
function create_containers() {

    for ((i = 1; i <= ${INSTANCE_NUM}; i++)); do
        local instance_name=${INSTANCE_PREFIX}-${i}
        # 检测容器是否存在
        sudo docker ps --format '{{json .Names}}' | grep -E "^\"${instance_name}\"$" 2>&1 >/dev/null
        if [[ $? -ne 0 ]]; then
            local container_id=$(sudo docker run -d --name ${instance_name} --network ${NET_NAME} ${IMG_NAME}:${IMG_TAG})
            if [[ $? -eq 0 ]]; then
                LOG_INFO "实例：${instance_name}创建成功"
                continue
            fi
        fi

        LOG_INFO "实例：${instance_name}已存在"
    done
    LOG_INFO "->>> 容器创建完成 <<<-"

    LOG_INFO "交互界面：docker exec -it 容器名 /bin/bash"
}

# 比较Dockerfile和image之间的
# 时间状态，判断是否需要重新构建
function cmp_time_stat() {
    # 获取镜像的构建时间戳
    local img_date=$(docker image inspect -f '{{json .Metadata.LastTagTime}}' ${IMG_NAME}:${IMG_TAG})
    local img_date_format=$(echo ${img_date} | sed -E 's|^"([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}:[0-9]{2}:[0-9]{2}).*"$|\1 \2|')
    local img_timestamp=$(date -d "${img_date_format}" +%s)

    # 获取构建列表
    local build_files_list=$(find ./build -maxdepth 1 -type f)

    # 遍历构建列表下的目录和文件
    for file in ${build_files_list}; do
        # 提取文件的修改时间
        local file_date=$(stat -c '%y' "$file")
        local file_format=$(echo ${file_date} | sed -E 's|^([0-9]{4}-[0-9]{2}-[0-9]{2}) ([0-9]{2}:[0-9]{2}:[0-9]{2}).*$|\1 \2|')

        # 转换为时间戳
        local file_timestamp=$(date -d "${file_format}" +%s)

        # 如果文件时间晚于或等于镜像时间，则返回成功
        if [[ ${img_timestamp} -le ${file_timestamp} ]]; then
            echo "文件：${file} 已被更新"
            return 0
        fi
    done

    return 1
}

function main() {
    echo '------------------------------'
    # 判断权限
    sudo_permission_check

    # 解析参数
    parse_argus $1 $2

    # 创建网络
    create_docker_network

    # 构建镜像
    build_image

    # 创建实例
    create_containers
}

main $@
