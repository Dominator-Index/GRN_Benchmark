#!/usr/bin/env python3
"""
Generate complete ground truth files for Dream4 networks
Uses GeneNetWeaver (Java) + Python for comprehensive extraction

Output Directory: /zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/ground_truth/
"""

import os
import sys
import json
import subprocess
import numpy as np
import pandas as pd
import xml.etree.ElementTree as ET
from pathlib import Path


class Dream4GroundTruthGenerator:
    """Generate ground truth files from Dream4 XML networks"""
    
    def __init__(self, 
                 gnw_jar_path="/zhoujingbo/oyzl/discrete_diffusion/Foreign-Datasets/genenetweaver/gnw-3.1.2b.jar",
                 dream4_dir="/zhoujingbo/oyzl/discrete_diffusion/Foreign-Datasets/genenetweaver/src/ch/epfl/lis/networks/dream4",
                 output_base="/zhoujingbo/oyzl/discrete_diffusion/GRN_Benchmark/ground_truth"):
        
        self.gnw_jar = gnw_jar_path
        self.dream4_dir = Path(dream4_dir)
        self.output_base = Path(output_base)
        self.output_base.mkdir(parents=True, exist_ok=True)
        
        # Check Java
        try:
            subprocess.run(['java', '-version'], capture_output=True, check=True)
            print("✓ Java is available")
        except:
            raise RuntimeError("❌ Java not found. Please install Java.")
            
        # Check GNW JAR
        if not Path(self.gnw_jar).exists():
            raise FileNotFoundError(f"❌ GNW JAR not found: {self.gnw_jar}")
        print(f"✓ GNW JAR found: {self.gnw_jar}")
    
    def extract_network_from_xml(self, xml_path):
        """Extract signed network from SBML XML file
        
        Returns:
            edges: List of [Gene1, Gene2, Type] where Type is '+' or '-'
        """
        tree = ET.parse(xml_path)
        root = tree.getroot()
        ns = {'sbml': 'http://www.sbml.org/sbml/level2'}
        
        edges = []
        reactions = root.findall('.//sbml:reaction', ns)
        
        for reaction in reactions:
            reaction_id = reaction.attrib.get('id', '')
            if 'degradation' in reaction_id or '_' not in reaction_id:
                continue
                
            target = reaction_id.split('_')[0]
            if not target:
                continue
                
            # Get regulators
            modifiers = reaction.findall('.//sbml:modifierSpeciesReference', ns)
            regulators = []
            for mod in modifiers:
                source = mod.attrib.get('species', '')
                if source and source != '_void_':
                    regulators.append(source)
            
            if not regulators:
                continue
            
            # Parse kinetic parameters to determine activation/repression
            kinetic_law = reaction.find('.//sbml:kineticLaw', ns)
            if kinetic_law is not None:
                params = {}
                for param in kinetic_law.findall('.//sbml:parameter', ns):
                    param_id = param.attrib.get('id', '')
                    param_value = float(param.attrib.get('value', 0))
                    params[param_id] = param_value
                
                module_idx = 1
                used_regulators = set()
                
                while f'numActivators_{module_idx}' in params or f'numDeactivators_{module_idx}' in params:
                    n_act = int(params.get(f'numActivators_{module_idx}', 0))
                    n_deact = int(params.get(f'numDeactivators_{module_idx}', 0))
                    
                    total_in_module = n_act + n_deact
                    available_regs = [r for r in regulators if r not in used_regulators]
                    
                    for i in range(min(total_in_module, len(available_regs))):
                        reg = available_regs[i]
                        sign = '+' if i < n_act else '-'
                        edges.append([reg, target, sign])
                        used_regulators.add(reg)
                    
                    module_idx += 1
                
                # Unassigned regulators default to activation
                for reg in regulators:
                    if reg not in used_regulators:
                        edges.append([reg, target, '+'])
            else:
                # No kinetic law - all activation
                for reg in regulators:
                    edges.append([reg, target, '+'])
        
        return edges
    
    def generate_edge_list_signed(self, edges, output_path):
        """Generate signed edge list: Gene1 Gene2 Sign"""
        with open(output_path, 'w') as f:
            f.write("Gene1\tGene2\tType\n")
            for edge in edges:
                f.write(f"{edge[0]}\t{edge[1]}\t{edge[2]}\n")
        print(f"  ✓ Signed edge list: {output_path}")
    
    def generate_edge_list_unsigned(self, edges, output_path):
        """Generate unsigned edge list: Gene1 Gene2 1"""
        with open(output_path, 'w') as f:
            f.write("Gene1\tGene2\tEdge\n")
            for edge in edges:
                f.write(f"{edge[0]}\t{edge[1]}\t1\n")
        print(f"  ✓ Unsigned edge list: {output_path}")
    
    def generate_adjacency_matrix(self, edges, gene_names, output_path):
        """Generate binary adjacency matrix (genes x genes)"""
        n = len(gene_names)
        adj_matrix = np.zeros((n, n), dtype=int)
        
        gene_to_idx = {gene: i for i, gene in enumerate(gene_names)}
        
        for edge in edges:
            source, target, _ = edge
            if source in gene_to_idx and target in gene_to_idx:
                i, j = gene_to_idx[source], gene_to_idx[target]
                adj_matrix[i, j] = 1
        
        # Save as TSV
        df = pd.DataFrame(adj_matrix, index=gene_names, columns=gene_names)
        df.to_csv(output_path, sep='\t')
        print(f"  ✓ Adjacency matrix: {output_path}")
        
        return adj_matrix
    
    def generate_beeline_format(self, edges, output_path):
        """Generate BEELINE-compatible refNetwork.csv"""
        df = pd.DataFrame(edges, columns=['Gene1', 'Gene2', 'Type'])
        df.to_csv(output_path, index=False)
        print(f"  ✓ BEELINE refNetwork: {output_path}")
    
    def get_gene_names_from_xml(self, xml_path):
        """Extract all gene names from XML"""
        tree = ET.parse(xml_path)
        root = tree.getroot()
        ns = {'sbml': 'http://www.sbml.org/sbml/level2'}
        
        species = root.findall('.//sbml:species', ns)
        genes = []
        for sp in species:
            gene_id = sp.attrib.get('id', '')
            if gene_id and gene_id != '_void_':
                genes.append(gene_id)
        
        return sorted(genes)
    
    def generate_statistics(self, edges, gene_names, output_path):
        """Generate network statistics"""
        n_genes = len(gene_names)
        n_edges = len(edges)
        n_activation = sum(1 for e in edges if e[2] == '+')
        n_repression = sum(1 for e in edges if e[2] == '-')
        
        # Compute in-degree and out-degree
        in_degree = {gene: 0 for gene in gene_names}
        out_degree = {gene: 0 for gene in gene_names}
        
        for edge in edges:
            source, target, _ = edge
            out_degree[source] += 1
            in_degree[target] += 1
        
        stats = {
            'network_name': output_path.parent.name,
            'num_genes': n_genes,
            'num_edges': n_edges,
            'num_activation_edges': n_activation,
            'num_repression_edges': n_repression,
            'edge_density': n_edges / (n_genes * (n_genes - 1)),
            'avg_in_degree': np.mean(list(in_degree.values())),
            'avg_out_degree': np.mean(list(out_degree.values())),
            'max_in_degree': max(in_degree.values()),
            'max_out_degree': max(out_degree.values()),
        }
        
        with open(output_path, 'w') as f:
            json.dump(stats, f, indent=2)
        
        print(f"  ✓ Statistics: {output_path}")
        return stats
    
    def process_network(self, network_name):
        """Process a single Dream4 network and generate all ground truth files
        
        Args:
            network_name: e.g., 'insilico_size10_1'
        """
        print(f"\n{'='*60}")
        print(f"Processing: {network_name}")
        print('='*60)
        
        xml_path = self.dream4_dir / f"{network_name}.xml"
        if not xml_path.exists():
            print(f"❌ XML file not found: {xml_path}")
            return
        
        # Create output directory
        output_dir = self.output_base / network_name
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Extract network
        print("Extracting network from XML...")
        edges = self.extract_network_from_xml(xml_path)
        gene_names = self.get_gene_names_from_xml(xml_path)
        
        print(f"  Found {len(edges)} edges, {len(gene_names)} genes")
        
        # Generate all formats
        print("\nGenerating ground truth files...")
        
        # 1. Signed edge list (TSV)
        self.generate_edge_list_signed(
            edges, 
            output_dir / f"{network_name}_goldstandard_signed.tsv"
        )
        
        # 2. Unsigned edge list (TSV)
        self.generate_edge_list_unsigned(
            edges,
            output_dir / f"{network_name}_goldstandard.tsv"
        )
        
        # 3. Adjacency matrix (TSV)
        self.generate_adjacency_matrix(
            edges,
            gene_names,
            output_dir / f"{network_name}_adjacency_matrix.tsv"
        )
        
        # 4. BEELINE format (CSV)
        self.generate_beeline_format(
            edges,
            output_dir / "refNetwork.csv"
        )
        
        # 5. Statistics (JSON)
        stats = self.generate_statistics(
            edges,
            gene_names,
            output_dir / f"{network_name}_statistics.json"
        )
        
        # Print summary
        print(f"\n{'='*60}")
        print(f"Summary for {network_name}:")
        print(f"  Genes: {stats['num_genes']}")
        print(f"  Edges: {stats['num_edges']} (Activation: {stats['num_activation_edges']}, Repression: {stats['num_repression_edges']})")
        print(f"  Density: {stats['edge_density']:.4f}")
        print(f"  Avg in-degree: {stats['avg_in_degree']:.2f}")
        print(f"  Avg out-degree: {stats['avg_out_degree']:.2f}")
        print('='*60)
        
        return output_dir
    
    def process_all_size10(self):
        """Process all size10 networks (1-5)"""
        for i in range(1, 6):
            self.process_network(f"insilico_size10_{i}")
    
    def process_all_size100(self):
        """Process all size100 networks (1-5)"""
        for i in range(1, 6):
            self.process_network(f"insilico_size100_{i}")
    
    def generate_summary_report(self):
        """Generate a summary report of all processed networks"""
        summary_file = self.output_base / "SUMMARY.md"
        
        with open(summary_file, 'w') as f:
            f.write("# Dream4 Ground Truth Summary\n\n")
            f.write(f"**Generated**: {pd.Timestamp.now()}\n\n")
            f.write("## Networks Processed\n\n")
            
            for network_dir in sorted(self.output_base.iterdir()):
                if not network_dir.is_dir():
                    continue
                
                stats_file = network_dir / f"{network_dir.name}_statistics.json"
                if stats_file.exists():
                    with open(stats_file) as sf:
                        stats = json.load(sf)
                    
                    f.write(f"### {stats['network_name']}\n\n")
                    f.write(f"- **Genes**: {stats['num_genes']}\n")
                    f.write(f"- **Edges**: {stats['num_edges']}\n")
                    f.write(f"  - Activation: {stats['num_activation_edges']}\n")
                    f.write(f"  - Repression: {stats['num_repression_edges']}\n")
                    f.write(f"- **Edge Density**: {stats['edge_density']:.4f}\n")
                    f.write(f"- **Avg In-Degree**: {stats['avg_in_degree']:.2f}\n")
                    f.write(f"- **Avg Out-Degree**: {stats['avg_out_degree']:.2f}\n\n")
                    
                    f.write("**Files generated**:\n")
                    for file in sorted(network_dir.iterdir()):
                        if file.is_file():
                            f.write(f"- `{file.name}`\n")
                    f.write("\n")
        
        print(f"\n✓ Summary report: {summary_file}")


def main():
    print("=" * 60)
    print("Dream4 Ground Truth Generator")
    print("=" * 60)
    
    generator = Dream4GroundTruthGenerator()
    
    # Process size10 networks
    print("\n🔍 Processing Size10 Networks (1-5)...")
    generator.process_all_size10()
    
    # Process size100 networks
    print("\n🔍 Processing Size100 Networks (1-5)...")
    generator.process_all_size100()
    
    # Generate summary
    print("\n📊 Generating summary report...")
    generator.generate_summary_report()
    
    print("\n" + "=" * 60)
    print("✅ All ground truth files generated successfully!")
    print("=" * 60)
    print(f"\nOutput directory: {generator.output_base}")
    print("\nGenerated files for each network:")
    print("  1. *_goldstandard_signed.tsv    - Signed edge list (Gene1, Gene2, Type)")
    print("  2. *_goldstandard.tsv            - Unsigned edge list (Gene1, Gene2, 1)")
    print("  3. *_adjacency_matrix.tsv        - Binary adjacency matrix")
    print("  4. refNetwork.csv                - BEELINE format")
    print("  5. *_statistics.json             - Network statistics")
    print("\nSummary: ground_truth/SUMMARY.md")


if __name__ == "__main__":
    main()
