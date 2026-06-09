#!/usr/bin/env python3
import argparse
import os
import sys


def q8_8_hex_from_float(x):
    # x expected in range 0.0..1.0
    q = int(round(x * 256.0))

    if q < 0:
        q = 0
    elif q > 32767:
        q = 32767

    return f"{q & 0xFFFF:04x}"


def save_hex_and_label(pixels_784, label, out_hex, out_label):
    if len(pixels_784) != 784:
        raise RuntimeError(f"Expected 784 pixels, got {len(pixels_784)}")

    os.makedirs(os.path.dirname(out_hex), exist_ok=True)

    with open(out_hex, "w") as f:
        for p in pixels_784:
            f.write(q8_8_hex_from_float(float(p)) + "\n")

    with open(out_label, "w") as f:
        f.write(str(label) + "\n")

    print(f"[OK] wrote image hex : {out_hex}")
    print(f"[OK] wrote label     : {out_label}")
    print(f"[INFO] label         : {label}")


def load_from_torchvision(index, root):
    try:
        from torchvision import datasets, transforms
    except Exception as e:
        print("[ERROR] torchvision is not available.")
        print("Install it first or use --image with a 28x28 PNG.")
        print(f"Import error: {e}")
        sys.exit(1)

    transform = transforms.ToTensor()

    dataset = datasets.MNIST(
        root=root,
        train=False,
        download=True,
        transform=transform
    )

    img_tensor, label = dataset[index]

    # img_tensor shape is [1, 28, 28], values 0.0..1.0
    pixels = img_tensor.squeeze(0).reshape(-1).tolist()
    return pixels, int(label)


def load_from_image(path):
    try:
        from PIL import Image
    except Exception as e:
        print("[ERROR] Pillow is not available.")
        print("Install it first with: python3 -m pip install --user pillow")
        print(f"Import error: {e}")
        sys.exit(1)

    img = Image.open(path).convert("L")
    img = img.resize((28, 28))

    # Convert 0..255 to 0.0..1.0
    raw = list(img.getdata())
    pixels = [p / 255.0 for p in raw]

    # Unknown label for custom image.
    return pixels, -1


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--index",
        type=int,
        default=0,
        help="MNIST test dataset index if using torchvision. Default: 0"
    )

    parser.add_argument(
        "--mnist-root",
        default="mnist_data",
        help="MNIST download/cache folder. Default: mnist_data"
    )

    parser.add_argument(
        "--image",
        default=None,
        help="Optional custom 28x28 or arbitrary image path. If set, torchvision MNIST is not used."
    )

    parser.add_argument(
        "--out-hex",
        default="generated_hex/mnist_sample_hex.txt"
    )

    parser.add_argument(
        "--out-label",
        default="generated_hex/mnist_sample_label.txt"
    )

    args = parser.parse_args()

    if args.image is not None:
        pixels, label = load_from_image(args.image)
    else:
        pixels, label = load_from_torchvision(args.index, args.mnist_root)

    save_hex_and_label(pixels, label, args.out_hex, args.out_label)


if __name__ == "__main__":
    main()
