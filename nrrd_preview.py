#!/usr/bin/env python3
"""
NRRD 3D mask preview generator.
Loads NRRD file, renders each unique mask label with a different color,
and outputs a JPEG preview image.
"""

import sys
import argparse
from pathlib import Path

import numpy as np
import nrrd
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import matplotlib.patches as mpatches


def load_nrrd(filepath: str) -> tuple[np.ndarray, dict]:
    """Load NRRD file and return data + header."""
    data, header = nrrd.read(filepath)
    return data, header


def get_distinct_colors(n: int) -> list:
    """Generate n distinct colors for mask labels."""
    if n <= 10:
        # Use tab10 colormap for small number of labels
        cmap = plt.cm.tab10
        return [cmap(i) for i in range(n)]
    else:
        # Use tab20 + extra for more labels
        cmap = plt.cm.tab20
        colors = [cmap(i) for i in range(min(n, 20))]
        if n > 20:
            cmap2 = plt.cm.Set3
            colors.extend([cmap2(i) for i in range(n - 20)])
        return colors


def render_slices(data: np.ndarray, output_path: str, dpi: int = 100):
    """
    Render 3D mask data as a grid of slices with colored labels.
    Shows axial (XY), coronal (XZ), and sagittal (YZ) views.
    """
    # Get unique labels (excluding background 0)
    unique_labels = np.unique(data)
    unique_labels = unique_labels[unique_labels != 0]
    
    if len(unique_labels) == 0:
        # Empty mask - just show middle slices in grayscale
        fig, axes = plt.subplots(1, 3, figsize=(12, 4))
        mid = [s // 2 for s in data.shape]
        
        axes[0].imshow(data[mid[0], :, :], cmap='gray')
        axes[0].set_title(f'Axial (z={mid[0]})')
        axes[1].imshow(data[:, mid[1], :], cmap='gray')
        axes[1].set_title(f'Coronal (y={mid[1]})')
        axes[2].imshow(data[:, :, mid[2]], cmap='gray')
        axes[2].set_title(f'Sagittal (x={mid[2]})')
        
        for ax in axes:
            ax.axis('off')
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=dpi, bbox_inches='tight', format='jpeg')
        plt.close()
        return
    
    # Create color map for labels
    colors = get_distinct_colors(len(unique_labels))
    label_to_color = {label: colors[i] for i, label in enumerate(unique_labels)}
    
    # Create RGBA image for each view
    def colorize_slice(slice_2d: np.ndarray) -> np.ndarray:
        """Convert label slice to RGBA image."""
        rgba = np.zeros((*slice_2d.shape, 4))
        for label, color in label_to_color.items():
            mask = slice_2d == label
            rgba[mask] = color
        return rgba
    
    # Get middle slices and slices at 25% and 75%
    shape = data.shape
    slice_positions = [
        shape[0] // 4, shape[0] // 2, 3 * shape[0] // 4  # Axial
    ]
    
    # Create figure with 3x3 grid: 3 axial slices + center coronal + center sagittal
    fig, axes = plt.subplots(2, 3, figsize=(12, 8))
    
    # Top row: 3 axial slices
    for i, z in enumerate(slice_positions):
        if z < shape[0]:
            rgba = colorize_slice(data[z, :, :])
            axes[0, i].imshow(rgba, origin='lower')
            axes[0, i].set_title(f'Axial z={z}/{shape[0]}')
        axes[0, i].axis('off')
    
    # Bottom row: coronal, sagittal, legend
    mid_y = shape[1] // 2
    mid_x = shape[2] // 2
    
    rgba_coronal = colorize_slice(data[:, mid_y, :])
    axes[1, 0].imshow(rgba_coronal, origin='lower')
    axes[1, 0].set_title(f'Coronal y={mid_y}/{shape[1]}')
    axes[1, 0].axis('off')
    
    rgba_sagittal = colorize_slice(data[:, :, mid_x])
    axes[1, 1].imshow(rgba_sagittal, origin='lower')
    axes[1, 1].set_title(f'Sagittal x={mid_x}/{shape[2]}')
    axes[1, 1].axis('off')
    
    # Legend
    axes[1, 2].axis('off')
    patches = [
        mpatches.Patch(color=color, label=f'Label {label}')
        for label, color in label_to_color.items()
    ]
    # Limit legend items if too many
    if len(patches) > 15:
        patches = patches[:14] + [mpatches.Patch(color='gray', label=f'... +{len(patches)-14} more')]
    
    axes[1, 2].legend(handles=patches, loc='center', fontsize=8)
    axes[1, 2].set_title(f'{len(unique_labels)} labels')
    
    # Add info text
    fig.suptitle(f'Shape: {shape[0]}×{shape[1]}×{shape[2]}', fontsize=10)
    
    plt.tight_layout()
    plt.savefig(output_path, dpi=dpi, bbox_inches='tight', format='jpeg', quality=85)
    plt.close()


def main():
    parser = argparse.ArgumentParser(description='Generate JPEG preview of NRRD 3D masks')
    parser.add_argument('input', help='Input NRRD file path')
    parser.add_argument('-o', '--output', help='Output JPEG path (default: input.jpg)')
    parser.add_argument('--dpi', type=int, default=100, help='Output DPI (default: 100)')
    args = parser.parse_args()
    
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    
    output_path = args.output or str(input_path.with_suffix('.jpg'))
    
    print(f"Loading: {input_path}")
    data, header = load_nrrd(str(input_path))
    print(f"Shape: {data.shape}, dtype: {data.dtype}")
    
    print(f"Rendering preview...")
    render_slices(data, output_path, dpi=args.dpi)
    print(f"Saved: {output_path}")


if __name__ == '__main__':
    main()
