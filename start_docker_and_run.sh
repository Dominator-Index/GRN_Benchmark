#!/bin/bash
# 在容器内启动 Docker daemon 并运行 BEELINE
# Usage: ./start_docker_and_run.sh

set -e

echo "=========================================="
echo "容器内 Docker 启动脚本"
echo "=========================================="
echo ""

# Check if we're in a container
if [ ! -f /.dockerenv ] && [ ! -d /var/run/secrets/kubernetes.io ]; then
    echo "⚠️  警告: 似乎不在容器环境中"
    echo "   如果在宿主机，直接运行 docker 即可，无需此脚本"
    read -p "继续? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "1. 检查环境..."
echo "   PID 1: $(ps -p 1 -o comm=)"
echo "   User: $(whoami)"
echo "   Docker version: $(docker --version 2>&1 | head -1)"
echo ""

# Check if Docker daemon is already running
if docker ps &>/dev/null; then
    echo "✓ Docker daemon 已经在运行"
    docker ps
    exit 0
fi

echo "2. 准备启动 Docker daemon..."

# Create necessary directories
mkdir -p /var/lib/docker
mkdir -p /tmp/docker-data

# Setup iptables legacy (避免 nftables 问题)
if command -v update-alternatives &>/dev/null; then
    echo "   配置 iptables legacy..."
    update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
fi

echo "3. 启动 Docker daemon..."
echo "   日志位置: /tmp/dockerd.log"

# Try to start dockerd with different options
DOCKERD_STARTED=false

# Method 1: Standard start
echo "   尝试标准启动..."
dockerd \
    --host=unix:///var/run/docker.sock \
    --storage-driver=vfs \
    > /tmp/dockerd.log 2>&1 &
DOCKERD_PID=$!

# Wait and check
sleep 10

if ps -p $DOCKERD_PID > /dev/null && [ -S /var/run/docker.sock ]; then
    echo "   ✓ Docker daemon 启动成功 (PID: $DOCKERD_PID)"
    DOCKERD_STARTED=true
else
    echo "   ✗ 标准启动失败"
    kill $DOCKERD_PID 2>/dev/null || true
    
    # Method 2: With custom data-root
    echo "   尝试使用自定义数据目录..."
    dockerd \
        --host=unix:///var/run/docker.sock \
        --data-root=/tmp/docker-data \
        --storage-driver=vfs \
        --iptables=false \
        > /tmp/dockerd.log 2>&1 &
    DOCKERD_PID=$!
    
    sleep 10
    
    if ps -p $DOCKERD_PID > /dev/null && [ -S /var/run/docker.sock ]; then
        echo "   ✓ Docker daemon 启动成功 (PID: $DOCKERD_PID)"
        DOCKERD_STARTED=true
    else
        echo "   ✗ 自定义启动失败"
        kill $DOCKERD_PID 2>/dev/null || true
    fi
fi

if [ "$DOCKERD_STARTED" = false ]; then
    echo ""
    echo "❌ Docker daemon 启动失败"
    echo ""
    echo "查看日志:"
    echo "  tail -50 /tmp/dockerd.log"
    echo ""
    echo "可能的原因:"
    echo "  1. 容器没有 privileged 权限"
    echo "  2. 缺少必要的内核模块"
    echo "  3. cgroup 配置问题"
    echo ""
    echo "解决方案:"
    echo "  1. 使用 privileged 模式运行容器"
    echo "  2. 挂载宿主机的 Docker socket"
    echo "  3. 在宿主机直接运行 BEELINE"
    exit 1
fi

echo ""
echo "4. 验证 Docker..."

# Check socket
if [ -S /var/run/docker.sock ]; then
    echo "   ✓ Docker socket: /var/run/docker.sock"
    ls -la /var/run/docker.sock
else
    echo "   ✗ Docker socket 不存在"
    exit 1
fi

# Test docker command
echo ""
echo "5. 测试 Docker 运行..."
if docker run --rm hello-world > /tmp/docker-test.log 2>&1; then
    echo "   ✓ Docker 测试成功"
    echo ""
    docker version
else
    echo "   ✗ Docker 测试失败"
    cat /tmp/docker-test.log
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ Docker 已就绪"
echo "=========================================="
echo ""
echo "Docker daemon PID: $DOCKERD_PID"
echo "Docker socket: /var/run/docker.sock"
echo ""
echo "现在可以运行 BEELINE:"
echo "  cd /zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/BEELINE"
echo "  python BLRunner.py --config config-files/config_dream4_size10_fast.yaml"
echo ""
echo "停止 Docker daemon:"
echo "  kill $DOCKERD_PID"
echo ""

# Optionally run BEELINE immediately
if [ "$1" = "--run-beeline" ]; then
    echo "自动运行 BEELINE..."
    cd /zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/BEELINE
    python BLRunner.py --config config-files/config_dream4_size10_fast.yaml
fi
