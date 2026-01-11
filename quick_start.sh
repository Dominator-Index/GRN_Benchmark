#!/bin/bash
# Quick Start Script for Dream4 BEELINE Benchmark
# Usage: ./quick_start.sh [size10_1|size100_1|all]

set -e

PYTHON="/zhoujingbo/miniconda3/envs/mdlm/bin/python"
BASE_DIR="/zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark"
BEELINE_DIR="$BASE_DIR/BEELINE"
GT_DIR="$BASE_DIR/ground_truth"

echo "=========================================="
echo "Dream4 BEELINE Benchmark - Quick Start"
echo "=========================================="

# Function to setup a network
setup_network() {
    local network=$1
    echo ""
    echo "Setting up $network..."
    
    # Create input directory
    mkdir -p "$BEELINE_DIR/inputs/dream4/$network"
    
    # Copy ground truth
    if [ -f "$GT_DIR/$network/refNetwork.csv" ]; then
        cp "$GT_DIR/$network/refNetwork.csv" "$BEELINE_DIR/inputs/dream4/$network/"
        echo "  ✓ Copied refNetwork.csv"
    else
        echo "  ❌ Ground truth not found for $network"
        echo "  Run: $PYTHON $BASE_DIR/generate_ground_truth.py"
        return 1
    fi
    
    # Check if expression data exists
    if [ ! -f "$BEELINE_DIR/inputs/dream4/$network/ExpressionData.csv" ]; then
        echo "  ⚠ ExpressionData.csv not found"
        echo "  You need to run data conversion first"
    else
        echo "  ✓ ExpressionData.csv exists"
    fi
    
    # Check pseudotime
    if [ ! -f "$BEELINE_DIR/inputs/dream4/$network/PseudoTime.csv" ]; then
        echo "  ⚠ PseudoTime.csv not found"
    else
        echo "  ✓ PseudoTime.csv exists"
    fi
}

# Function to run benchmark
run_benchmark() {
    local config=$1
    echo ""
    echo "Running BEELINE benchmark..."
    echo "Config: $config"
    
    cd "$BEELINE_DIR"
    
    # Run inference
    echo ""
    echo "Step 1: Running GRN inference algorithms..."
    python BLRunner.py --config "$config"
    
    # Run evaluation
    echo ""
    echo "Step 2: Evaluating results..."
    python BLEvaluator.py --config "$config" --auc --epr
    
    echo ""
    echo "✅ Benchmark completed!"
}

# Main
case "${1:-size10_1}" in
    "size10_1")
        setup_network "insilico_size10_1"
        echo ""
        echo "Ready to run! Use:"
        echo "  cd $BEELINE_DIR"
        echo "  python BLRunner.py --config config-files/config_dream4_size10_fast.yaml"
        ;;
    
    "size100_1")
        setup_network "insilico_size100_1"
        echo ""
        echo "Ready to run! Use:"
        echo "  cd $BEELINE_DIR"
        echo "  python BLRunner.py --config config-files/config_dream4_size100.yaml"
        ;;
    
    "all")
        for i in {1..5}; do
            setup_network "insilico_size10_$i"
        done
        for i in {1..5}; do
            setup_network "insilico_size100_$i"
        done
        ;;
    
    "run")
        run_benchmark "${2:-config-files/config_dream4_size10_fast.yaml}"
        ;;
    
    *)
        echo "Usage: $0 [size10_1|size100_1|all|run]"
        echo ""
        echo "Examples:"
        echo "  $0 size10_1              # Setup size10_1 network"
        echo "  $0 all                   # Setup all networks"
        echo "  $0 run config.yaml       # Run benchmark with config"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Quick Reference:"
echo "=========================================="
echo "Ground Truth: $GT_DIR"
echo "BEELINE: $BEELINE_DIR"
echo "Python: $PYTHON"
echo ""
echo "View ground truth summary:"
echo "  cat $GT_DIR/SUMMARY.md"
echo ""
echo "View network statistics:"
echo "  cat $GT_DIR/insilico_size10_1/insilico_size10_1_statistics.json"
