#!/bin/bash
# 检查 BEELINE 是否可以在本地运行

echo "=========================================="
echo "BEELINE 本地运行就绪检查"
echo "=========================================="
echo ""

READY=true

# 1. 检查必要文件
echo 1. 检查........"

FILES=(
    "BEELINE/BLRunner.py"
    "BEELINE/BLEvaluator.py"
    "BEELINE/config-files/config_dream4_size10_fast.yaml"
    "ground_truth/insilico_size10_1/refNetwork.csv"
    "convert_dream4_to_beeline.py"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file (缺失)"
        READY=false
    fi
done
echo ""

# 2. 检查数据文件
echo "2. 检查数据文件..."
if [ -f "../dataset/Dream4/insilico_size10_1_model_data.json" ]; then
    echo "   ✓ Dream4 数据"
else
    echo "   ✗ Dream4 数据缺失"
    READY=false
fi
echo ""

# 3. 检查 Python 环境
echo "3. 检查 Python 环境..."
PYTHON="/zhoujingbo/miniconda3/envs/mdlm/bin/python"
if [ -x "$PYTHON" ]; then
    echo "   ✓ Python: $PYTHON"
    $PYTHON --version
else
    echo "   ✗ Python 环境不可用"
    READY=false
fi
echo ""

# 4. 检查 Docker (本地运行必需)
echo "4. 检查 Docker (本地必需)..."
if command -v docker &> /dev/null; then
    echo "   ✓ Docker 已安装: $(docker --version | head -1)"
    
    if docker ps &> /dev/null; then
        echo "   ✓ Docker 可运行 (无需 sudo)"
    else
        echo "   ⚠ Docker 需要权限或服务未启动"
        echo "   本地运行需要: sudo systemctl start docker"
        READY=false
    fi
else
    echo "   ✗ Docker 未安装"
    echo "   本地运行必须安装 Docker"
    READY=false
fi
echo ""

# 5. 检查脚本
echo "5. 检查辅助脚本..."
SCRIPTS=(
    "generate_ground_truth.py"
    "diagnose_docker.sh"
    "start_docker_and_run.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "   ✓ $script"
    else
        echo "   ⚠ $script (可选)"
    fi
done
echo ""

# 总结
echo "=========================================="
if [ "$READY" = true ]; then
    echo "✅ 可以转移到本地运行！"
    echo "=========================================="
    echo ""
    echo "转移清单:"
    echo "  1. 整个 GRN_Benchmark 目录"
    echo "  2. dataset/Dream4/ 目录"
    echo "  3. 确保本地有 Docker 和 Python"
    echo ""
    echo "本地运行步骤:"
    echo "  1. 安装 Docker (如果没有)"
    echo "  2. 启动 Docker: systemctl start docker"
    echo "  3. cd GRN_Benchmark/BEELINE"
    echo "  4. python BLRunner.py --config config-files/config_dream4_size10_fast.yaml"
else
    echo "⚠️  有缺失项，需要补充"
    echo "=========================================="
    echo ""
    echo "缺失项需要在本地补充:"
    echo "  - 安装 Docker"
    echo "  - 安装 Python 3.x"
    echo "  - 安装依赖: pip install pandas numpy pyyaml"
fi
echo ""

exit $([ "$READY" = true ] && echo 0 || echo 1)
