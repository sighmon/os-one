#!/usr/bin/env python3
"""
Convert HuggingFace models to MLX format for Apple Silicon
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

try:
    from mlx_lm import convert
except ImportError:
    print("Error: mlx-lm not installed")
    print("Install with: pip install mlx-lm")
    sys.exit(1)

QUANTIZATION_INFO = {
    None: "No quantization (full precision, largest size)",
    "q4": "4-bit quantization (recommended for iPhone, ~75% size reduction)",
    "q8": "8-bit quantization (recommended for iPad/Mac, ~50% size reduction)",
}

def get_model_info(model_path: Path) -> dict:
    """Extract model information from config.json"""
    config_path = model_path / "config.json"

    if not config_path.exists():
        print(f"⚠️  Warning: config.json not found at {config_path}")
        return {}

    with open(config_path) as f:
        return json.load(f)

def estimate_size(model_path: Path, quantize: Optional[str]) -> float:
    """Estimate output model size in GB"""
    # Get original size
    total_size = sum(f.stat().st_size for f in model_path.rglob("*.safetensors") if f.is_file())
    original_gb = total_size / (1024**3)

    # Estimate quantized size
    if quantize == "q4":
        return original_gb * 0.25
    elif quantize == "q8":
        return original_gb * 0.5
    else:
        return original_gb

def convert_model(
    model_path: Path,
    output_path: Path,
    quantize: Optional[str] = None,
    dequantize: bool = False
) -> Path:
    """
    Convert model to MLX format

    Args:
        model_path: Path to HuggingFace model
        output_path: Output path for MLX model
        quantize: Quantization type ("q4", "q8", or None)
        dequantize: Whether to dequantize (for debugging)

    Returns:
        Path to converted model
    """
    print(f"🔄 Converting {model_path.name} to MLX format...")
    print(f"📊 Quantization: {quantize or 'None'}")

    if quantize:
        print(f"ℹ️  {QUANTIZATION_INFO[quantize]}")

    # Get model info
    info = get_model_info(model_path)
    if info:
        print(f"📝 Model architecture: {info.get('model_type', 'unknown')}")
        print(f"📝 Hidden size: {info.get('hidden_size', 'unknown')}")
        print(f"📝 Layers: {info.get('num_hidden_layers', 'unknown')}")

    # Estimate output size
    estimated_size = estimate_size(model_path, quantize)
    print(f"📦 Estimated output size: {estimated_size:.2f} GB")

    try:
        # Perform conversion
        print("\n⏳ Converting... (this may take several minutes)")

        output_path.mkdir(parents=True, exist_ok=True)

        convert(
            model_path=str(model_path),
            mlx_path=str(output_path),
            quantize=quantize,
            q_group_size=64,  # Group size for quantization
            q_bits=4 if quantize == "q4" else 8 if quantize == "q8" else None,
            dequantize=dequantize,
            upload_repo=None
        )

        print(f"\n✅ Conversion complete!")
        print(f"📁 Output: {output_path}")

        # Verify output
        verify_conversion(output_path)

        return output_path

    except Exception as e:
        print(f"\n❌ Conversion failed: {e}")
        sys.exit(1)

def verify_conversion(output_path: Path) -> bool:
    """Verify converted MLX model"""
    print("\n🔍 Verifying converted model...")

    required_files = ["config.json", "tokenizer.json"]
    mlx_files = list(output_path.glob("*.safetensors"))

    success = True

    for file in required_files:
        file_path = output_path / file
        if file_path.exists():
            print(f"  ✅ {file}")
        else:
            print(f"  ❌ {file} - MISSING")
            success = False

    if mlx_files:
        total_size = sum(f.stat().st_size for f in mlx_files) / (1024**3)
        print(f"  ✅ MLX weights: {len(mlx_files)} file(s), {total_size:.2f} GB")
    else:
        print(f"  ❌ No MLX weight files found")
        success = False

    if success:
        print("\n✅ Model verification passed!")
    else:
        print("\n⚠️  Model verification failed - some files missing")

    return success

def main():
    parser = argparse.ArgumentParser(
        description="Convert HuggingFace models to MLX format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert to MLX with 4-bit quantization (iPhone)
  python convert_to_mlx.py models/Qwen/Qwen2.5-1.5B-Instruct --quantize q4

  # Convert to MLX with 8-bit quantization (iPad/Mac)
  python convert_to_mlx.py models/meta-llama/Llama-3.2-3B-Instruct --quantize q8

  # Convert without quantization (largest size, best quality)
  python convert_to_mlx.py models/google/gemma-2-2b-it

Quantization recommendations:
  iPhone 15 Pro:     --quantize q4 (4-bit, ~25% original size)
  iPad Pro M2:       --quantize q8 (8-bit, ~50% original size)
  MacBook M1+:       --quantize q8 or None (full precision)

Size estimates:
  1.5B model (q4):   ~900 MB
  1.5B model (q8):   ~1.4 GB
  3B model (q4):     ~1.8 GB
  3B model (q8):     ~2.5 GB
        """
    )

    parser.add_argument(
        "model_path",
        type=Path,
        help="Path to HuggingFace model directory"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output path for MLX model (default: <model_path>-mlx-<quant>)"
    )
    parser.add_argument(
        "--quantize",
        choices=["q4", "q8"],
        default=None,
        help="Quantization type (q4 for mobile, q8 for desktop)"
    )
    parser.add_argument(
        "--dequantize",
        action="store_true",
        help="Dequantize weights (for debugging)"
    )

    args = parser.parse_args()

    # Validate input
    if not args.model_path.exists():
        print(f"❌ Error: Model path does not exist: {args.model_path}")
        sys.exit(1)

    if not args.model_path.is_dir():
        print(f"❌ Error: Model path must be a directory: {args.model_path}")
        sys.exit(1)

    # Determine output path
    if args.output is None:
        suffix = f"-mlx-{args.quantize}" if args.quantize else "-mlx"
        args.output = args.model_path.parent / f"{args.model_path.name}{suffix}"

    print("🚀 OS One Model Converter (MLX)")
    print("=" * 60)
    print(f"Input:  {args.model_path}")
    print(f"Output: {args.output}")
    print("=" * 60 + "\n")

    # Convert model
    output_path = convert_model(
        args.model_path,
        args.output,
        args.quantize,
        args.dequantize
    )

    print("\n" + "=" * 60)
    print("🎉 Conversion complete!")
    print(f"📁 MLX model: {output_path}")
    print("\nNext steps:")
    print("  1. Copy model to iOS device:")
    print(f"     adb push {output_path} /path/to/app/documents/")
    print("  2. Or add to Xcode project as a resource")
    print("  3. Select model in OS One settings")
    print("  4. Enable offline mode")

if __name__ == "__main__":
    main()
