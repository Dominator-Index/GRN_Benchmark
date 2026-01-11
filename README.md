# GRN Benchmark Tools

This repository contains tools and configurations for benchmarking Gene Regulatory Network (GRN) inference algorithms using the BEELINE framework, specifically adapted for Dream4 datasets.

## Contents
- `convert_dream4_to_beeline.py`: Converts Dream4 JSON data format (from the Discrete Diffusion project) to BEELINE-compatible CSV format.
- `run_dream4_benchmark.sh`: A shell script to automate the execution of BEELINE algorithms and evaluation.
- `BEELINE/`: The [BEELINE](https://github.com/murali-group/BEELINE) framework directory, including customized configuration files in `config-files/`.

## Requirements
- **Python 3.x** with `pandas`, `numpy`, and `lxml`.
- **Docker**: Required to run the GRN inference algorithms encapsulated in BEELINE containers.

## Usage

### 1. Data Preparation
Convert your Dream4 JSON data to BEELINE format:
```bash
python convert_dream4_to_beeline.py
```
This will generate `ExpressionData.csv`, `PseudoTime.csv`, and `refNetwork.csv` in the `BEELINE/inputs/` directory.

### 2. Run Benchmark
Execute the automated benchmark script:
```bash
bash run_dream4_benchmark.sh
```

### 3. View Results
Results (ranked edges and AUC scores) will be saved in `BEELINE/outputs/`.

## Adaptation Note
This toolset was developed as part of the [Discrete Diffusion](https://github.com/kuleshov-group/mdlm) project adaptation to evaluate model performance on biological network inference tasks.
# GRN_Benchmark
