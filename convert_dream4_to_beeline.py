#!/usr/bin/env python3
"""
Convert Dream4 JSON data to BEELINE input format
"""
import json
import pandas as pd
import numpy as np
import xml.etree.ElementTree as ET
from pathlib import Path

def extract_network_from_xml(xml_path):
    """Extract gene regulatory network from Dream4 XML file
    
    This function parses the SBML XML to extract regulatory edges.
    It determines activation (+) or repression (-) by analyzing the kinetic parameters.
    
    For each reaction (synthesis), modifiers are regulators.
    The kinetic parameters contain numActivators/numDeactivators to determine edge signs.
    """
    tree = ET.parse(xml_path)
    root = tree.getroot()
    
    # Namespace handling
    ns = {'sbml': 'http://www.sbml.org/sbml/level2'}
    
    edges = []
    reactions = root.findall('.//sbml:reaction', ns)
    
    for reaction in reactions:
        # Only process synthesis reactions (not degradation)
        reaction_id = reaction.attrib.get('id', '')
        if 'degradation' in reaction_id or '_' not in reaction_id:
            continue
            
        # Get target gene from reaction name (e.g., "G2_synthesis" -> "G2")
        target = reaction_id.split('_')[0]
        if not target or target == '':
            continue
            
        # Get modifiers (regulators)
        modifiers = reaction.findall('.//sbml:modifierSpeciesReference', ns)
        regulators = []
        for mod in modifiers:
            source = mod.attrib.get('species', '')
            if source and source != '_void_':
                regulators.append(source)
        
        if not regulators:
            continue
            
        # Get kinetic parameters to determine activation/repression
        kinetic_law = reaction.find('.//sbml:kineticLaw', ns)
        if kinetic_law is not None:
            params = {}
            for param in kinetic_law.findall('.//sbml:parameter', ns):
                param_id = param.attrib.get('id', '')
                param_value = float(param.attrib.get('value', 0))
                params[param_id] = param_value
            
            # Analyze each module to determine sign
            # Multiple modules can have different regulators
            module_idx = 1
            used_regulators = set()
            
            while f'numActivators_{module_idx}' in params or f'numDeactivators_{module_idx}' in params:
                n_act = int(params.get(f'numActivators_{module_idx}', 0))
                n_deact = int(params.get(f'numDeactivators_{module_idx}', 0))
                
                # Determine which regulators belong to this module
                total_in_module = n_act + n_deact
                available_regs = [r for r in regulators if r not in used_regulators]
                
                for i in range(min(total_in_module, len(available_regs))):
                    reg = available_regs[i]
                    # First n_act are activators, rest are deactivators
                    if i < n_act:
                        edges.append([reg, target, '+'])
                    else:
                        edges.append([reg, target, '-'])
                    used_regulators.add(reg)
                
                module_idx += 1
            
            # If no modules found or some regulators unassigned, mark as activation by default
            for reg in regulators:
                if reg not in used_regulators:
                    edges.append([reg, target, '+'])
        else:
            # No kinetic law - mark all as activation
            for reg in regulators:
                edges.append([reg, target, '+'])
    
    return edges

def convert_json_to_beeline(json_path, xml_path, output_dir):
    """Convert Dream4 JSON data to BEELINE format"""
    
    # Load JSON data
    with open(json_path, 'r') as f:
        data = json.load(f)
    
    gene_names = data['gene_names']
    expression_data = np.array(data['data'])  # shape: (n_samples, n_genes)
    
    print(f"Loaded {expression_data.shape[0]} samples, {expression_data.shape[1]} genes")
    
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # 1. Create ExpressionData.csv (genes x cells)
    # Transpose to get genes as rows, cells as columns
    expr_df = pd.DataFrame(
        expression_data.T,
        index=gene_names,
        columns=[f"Cell_{i}" for i in range(expression_data.shape[0])]
    )
    expr_df.to_csv(output_path / "ExpressionData.csv")
    print(f"✓ Saved ExpressionData.csv: {expr_df.shape[0]} genes × {expr_df.shape[1]} cells")
    
    # 2. Create PseudoTime.csv (dummy time values since we don't have real time info)
    # Use sequential indices as pseudo-time
    pseudo_time_df = pd.DataFrame({
        'PseudoTime1': np.arange(expression_data.shape[0])
    }, index=[f"Cell_{i}" for i in range(expression_data.shape[0])])
    pseudo_time_df.to_csv(output_path / "PseudoTime.csv")
    print(f"✓ Saved PseudoTime.csv: {pseudo_time_df.shape[0]} cells (dummy sequential time)")
    
    # 3. Create refNetwork.csv (ground truth network)
    if xml_path and Path(xml_path).exists():
        edges = extract_network_from_xml(xml_path)
        if edges:
            network_df = pd.DataFrame(edges, columns=['Gene1', 'Gene2', 'Type'])
            network_df.to_csv(output_path / "refNetwork.csv", index=False)
            print(f"✓ Saved refNetwork.csv: {len(edges)} edges")
        else:
            print("⚠ Warning: No edges extracted from XML")
    else:
        print("⚠ Warning: XML file not found, skipping refNetwork.csv")
    
    print(f"\n✓ All files saved to: {output_path}")
    return output_path

if __name__ == "__main__":
    # Paths
    json_path = "/zhoujingbo/oyzl/discrete_diffusion/dataset/Dream4/insilico_size10_1_model_data.json"
    xml_path = "/zhoujingbo/oyzl/discrete_diffusion/Foreign-Datasets/genenetweaver/src/ch/epfl/lis/networks/dream4/insilico_size10_1.xml"
    output_dir = "/zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/BEELINE/inputs/dream4/insilico_size10_1"
    
    output_path = convert_json_to_beeline(json_path, xml_path, output_dir)
    
    print("\n" + "="*60)
    print("Next steps:")
    print("="*60)
    print("1. Update BEELINE config file:")
    print("   - Set dataset_dir: 'dream4'")
    print("   - Set output_prefix to a meaningful name")
    print("\n2. Run BEELINE:")
    print("   cd /zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/BEELINE")
    print("   python BLRunner.py --config config-files/config.yaml")
    print("   python BLEvaluator.py --config config-files/config.yaml --auc")
