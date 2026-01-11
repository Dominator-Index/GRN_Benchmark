#!/bin/bash
# Docker 诊断和修复脚本
# Usage: ./diagnose_docker.sh

echo "=========================================="
echo "BEELINE Docker 环境诊断"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Status tracking
DOCKER_OK=false
SERVICE_OK=false
PERMISSION_OK=false
IMAGES_OK=false

# 1. Check if Docker command exists
echo "1. 检查 Docker 命令..."
if command -v docker &> /dev/null; then
    echo -e "   ${GREEN}✓${NC} Docker 命令存在: $(which docker)"
    docker --version
    DOCKER_OK=true
else
    echo -e "   ${RED}✗${NC} Docker 命令不存在"
    echo "   建议: sudo apt-get install docker.io"
fi
echo ""

# 2. Check Docker service
if [ "$DOCKER_OK" = true ]; then
    echo "2. 检查 Docker 服务..."
    if sudo systemctl is-active --quiet docker 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} Docker 服务正在运行"
        SERVICE_OK=true
    else
        echo -e "   ${RED}✗${NC} Docker 服务未运行"
        echo "   修复命令:"
        echo "   sudo systemctl start docker"
        echo "   sudo systemctl enable docker"
    fi
    echo ""
fi

# 3. Check Docker permissions
if [ "$DOCKER_OK" = true ]; then
    echo "3. 检查 Docker 权限..."
    if docker ps &> /dev/null; then
        echo -e "   ${GREEN}✓${NC} 当前用户可以运行 Docker (无需 sudo)"
        PERMISSION_OK=true
    else
        echo -e "   ${RED}✗${NC} 当前用户无法运行 Docker"
        echo "   当前用户: $(whoami)"
        
        if [ "$(whoami)" = "root" ]; then
            echo "   您是 root 用户，但 Docker 服务可能未启动"
        else
            echo "   修复命令:"
            echo "   sudo usermod -aG docker $USER"
            echo "   然后注销并重新登录，或运行: newgrp docker"
        fi
    fi
    echo ""
fi

# 4. Test Docker run
if [ "$PERMISSION_OK" = true ]; then
    echo "4. 测试 Docker 运行..."
    if docker run --rm hello-world &> /dev/null; then
        echo -e "   ${GREEN}✓${NC} Docker 可以正常运行容器"
    else
        echo -e "   ${YELLOW}⚠${NC} Docker 运行测试失败"
        echo "   尝试运行: docker run --rm hello-world"
    fi
    echo ""
fi

# 5. Check BEELINE images
if [ "$PERMISSION_OK" = true ]; then
    echo "5. 检查 BEELINE Docker 镜像..."
    BEELINE_IMAGES=$(docker images | grep grnbeeline | wc -l)
    
    if [ "$BEELINE_IMAGES" -gt 0 ]; then
        echo -e "   ${GREEN}✓${NC} 找到 $BEELINE_IMAGES 个 BEELINE 镜像"
        docker images | grep grnbeeline | head -5
        if [ "$BEELINE_IMAGES" -gt 5 ]; then
            echo "   ... (还有更多镜像)"
        fi
        IMAGES_OK=true
    else
        echo -e "   ${YELLOW}⚠${NC} 未找到 BEELINE 镜像"
        echo "   首次运行 BEELINE 时会自动下载镜像"
        echo "   或手动下载:"
        echo "   docker pull grnbeeline/pidc:base"
        echo "   docker pull grnbeeline/arboreto:base"
        echo "   docker pull grnbeeline/ppcor:base"
    fi
    echo ""
fi

# Summary
echo "=========================================="
echo "诊断摘要"
echo "=========================================="

if [ "$DOCKER_OK" = false ]; then
    echo -e "${RED}✗ Docker 未安装${NC}"
    echo ""
    echo "快速修复 (Ubuntu/Debian):"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y docker.io"
    echo "  sudo systemctl start docker"
    echo "  sudo systemctl enable docker"
    echo ""
    exit 1
fi

if [ "$SERVICE_OK" = false ]; then
    echo -e "${RED}✗ Docker 服务未运行${NC}"
    echo ""
    echo "快速修复:"
    echo "  sudo systemctl start docker"
    echo "  sudo systemctl enable docker"
    echo ""
    exit 1
fi

if [ "$PERMISSION_OK" = false ]; then
    echo -e "${RED}✗ Docker 权限问题${NC}"
    echo ""
    echo "快速修复:"
    if [ "$(whoami)" = "root" ]; then
        echo "  # 您是 root 用户，检查服务状态"
        echo "  sudo systemctl status docker"
    else
        echo "  sudo usermod -aG docker $USER"
        echo "  # 然后注销并重新登录，或运行:"
        echo "  newgrp docker"
    fi
    echo ""
    exit 1
fi

# All checks passed
echo -e "${GREEN}✓ 所有检查通过！${NC}"
echo ""
echo "Docker 环境已就绪，可以运行 BEELINE"
echo ""
echo "下一步:"
echo "  cd /zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/BEELINE"
echo "  python BLRunner.py --config config-files/config_dream4_size10_fast.yaml"
echo ""

if [ "$IMAGES_OK" = false ]; then
    echo -e "${YELLOW}提示:${NC} 首次运行会自动下载 Docker 镜像 (可能需要 10-30 分钟)"
    echo ""
fi

exit 0
