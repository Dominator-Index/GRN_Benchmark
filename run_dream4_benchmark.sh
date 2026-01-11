#!/bin/bash
# Run BEELINE benchmark on Dream4 insilico_size10_1 dataset

set -e

echo "=========================================="
echo "BEELINE Benchmark - Dream4 Size10"
echo "=========================================="

cd /zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/BEELINE

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed or not in PATH"
    echo "Please install Docker first: https://www.docker.com/"
    exit 1
fi

echo "✓ Docker is available"

# Check if data is prepared
if [ ! -f "inputs/dream4/insilico_size10_1/ExpressionData.csv" ]; then
    echo "❌ Error: Data not found. Run conversion script first."
    exit 1
fi

echo "✓ Data files found"

# Step 1: Run GRN inference
echo ""
echo "Step 1: Running GRN inference algorithms..."
echo "This may take a while (downloading Docker images on first run)..."
python BLRunner.py --config config-files/config_dream4_size10.yaml

# Step 2: Evaluate results
echo ""
echo "Step 2: Evaluating results (computing AUC metrics)..."
python BLEvaluator.py --config config-files/config_dream4_size10.yaml --auc

echo ""
echo "=========================================="
echo "✓ Benchmark completed!"
echo "=========================================="
echo "Results saved to: outputs/Dream4_insilico_size10_1/"
echo ""
echo "Check the following files:"
echo "  - outputs/Dream4_insilico_size10_1/*/rankedEdges.csv (predicted networks)"
echo "  - outputs/Dream4_insilico_size10_1/AUCs.csv (evaluation metrics)"
