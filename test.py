import sys

try:
    import torch
except ImportError:  # Provide a clear message if torch is missing.
    print("PyTorch is not installed.")
    sys.exit(1)


def main() -> None:
    print(f"PyTorch version: {torch.__version__}")


if __name__ == "__main__":
    main()
