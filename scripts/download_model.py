#!/usr/bin/env python3
"""
Download and convert HuggingFace models to MLX format for OS One
"""

import argparse
import sys
from pathlib import Path
from typing import Optional

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print("Error: huggingface_hub not installed")
    print("Install with: pip install huggingface-hub")
    sys.exit(1)

MODELS = {
    "qwen-1.5b": "Qwen/Qwen2.5-1.5B-Instruct",
    "qwen-3b": "Qwen/Qwen2.5-3B-Instruct",
    "gemma-2b": "google/gemma-2-2b-it",
    "llama-1b": "meta-llama/Llama-3.2-1B-Instruct",
    "llama-3b": "meta-llama/Llama-3.2-3B-Instruct",
}

def download_model(model_name: str, output_dir: Path, token: Optional[str] = None) -> Path:
    """
    Download model from HuggingFace

    Args:
        model_name: Model identifier from MODELS dict
        output_dir: Output directory for models
        token: Optional HuggingFace token for gated models

    Returns:
        Path to downloaded model
    """
    if model_name not in MODELS:
        raise ValueError(f"Unknown model: {model_name}. Choose from {list(MODELS.keys())}")

    repo_id = MODELS[model_name]
    print(f"📦 Downloading {repo_id}...")

    model_path = output_dir / repo_id

    try:
        downloaded_path = snapshot_download(
            repo_id=repo_id,
            local_dir=str(model_path),
            allow_patterns=["*.json", "*.safetensors", "tokenizer.model", "*.txt"],
            token=token,
        )

        print(f"✅ Model downloaded to: {downloaded_path}")
        print(f"📊 Model size: {get_dir_size(model_path):.2f} MB")

        return Path(downloaded_path)

    except Exception as e:
        print(f"❌ Error downloading model: {e}")
        if "gated" in str(e).lower():
            print("\n⚠️  This model requires authentication.")
            print("Get your token from: https://huggingface.co/settings/tokens")
            print("Then run with: --token YOUR_TOKEN")
        sys.exit(1)

def get_dir_size(path: Path) -> float:
    """Calculate directory size in MB"""
    total = sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
    return total / (1024 * 1024)

def verify_model(model_path: Path) -> bool:
    """Verify model has all required files"""
    required_files = ["config.json", "tokenizer.json", "model.safetensors"]

    print(f"\n🔍 Verifying model files...")

    missing = []
    for file in required_files:
        file_path = model_path / file
        if not file_path.exists():
            # Check for sharded safetensors
            if file == "model.safetensors":
                sharded = list(model_path.glob("model*.safetensors"))
                if sharded:
                    print(f"  ✅ {file} (sharded: {len(sharded)} files)")
                    continue

            missing.append(file)
            print(f"  ❌ {file} - MISSING")
        else:
            size = file_path.stat().st_size / (1024 * 1024)
            print(f"  ✅ {file} ({size:.2f} MB)")

    if missing:
        print(f"\n⚠️  Warning: Missing files: {', '.join(missing)}")
        return False

    print(f"\n✅ Model verification complete!")
    return True

def main():
    parser = argparse.ArgumentParser(
        description="Download HuggingFace models for OS One",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Download Qwen 2.5 1.5B (best for iPhone)
  python download_model.py qwen-1.5b

  # Download Llama 3.2 3B for iPad Pro
  python download_model.py llama-3b --output ./my_models

  # Download with HuggingFace token (for gated models)
  python download_model.py llama-3b --token hf_xxxxx

Available models:
  qwen-1.5b  - Qwen 2.5 1.5B Instruct (~1.1 GB)
  qwen-3b    - Qwen 2.5 3B Instruct (~2.0 GB)
  gemma-2b   - Google Gemma 2 2B (~1.5 GB)
  llama-1b   - Meta Llama 3.2 1B (~0.9 GB)
  llama-3b   - Meta Llama 3.2 3B (~2.1 GB)
        """
    )

    parser.add_argument(
        "model",
        choices=list(MODELS.keys()),
        help="Model to download"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("./models"),
        help="Output directory (default: ./models)"
    )
    parser.add_argument(
        "--token",
        type=str,
        default=None,
        help="HuggingFace token for gated models"
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify downloaded files"
    )

    args = parser.parse_args()

    # Create output directory
    args.output.mkdir(parents=True, exist_ok=True)

    print("🚀 OS One Model Downloader")
    print("=" * 50)

    # Download model
    model_path = download_model(args.model, args.output, args.token)

    # Verify if requested
    if args.verify or True:  # Always verify
        verify_model(model_path)

    print("\n" + "=" * 50)
    print("🎉 Download complete!")
    print(f"📁 Model location: {model_path}")
    print("\nNext steps:")
    print("  1. Convert to MLX format: python convert_to_mlx.py")
    print("  2. Copy to iOS device")
    print("  3. Enable offline mode in OS One settings")

if __name__ == "__main__":
    main()
