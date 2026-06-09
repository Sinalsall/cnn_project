#!/usr/bin/env python3
import argparse
import gzip
import os
import struct
import urllib.request


MNIST_IMAGES_URL = "https://storage.googleapis.com/cvdf-datasets/mnist/t10k-images-idx3-ubyte.gz"
MNIST_LABELS_URL = "https://storage.googleapis.com/cvdf-datasets/mnist/t10k-labels-idx1-ubyte.gz"


def download_if_missing(url, path):
    if os.path.exists(path):
        print(f"[OK] found existing file: {path}")
        return

    print(f"[INFO] downloading {url}")
    urllib.request.urlretrieve(url, path)
    print(f"[OK] downloaded: {path}")


def read_mnist_image(images_gz_path, index):
    with gzip.open(images_gz_path, "rb") as f:
        magic, num_images, rows, cols = struct.unpack(">IIII", f.read(16))

        if magic != 2051:
            raise RuntimeError(f"Invalid image magic number: {magic}")
        if rows != 28 or cols != 28:
            raise RuntimeError(f"Expected 28x28 images, got {rows}x{cols}")
        if index < 0 or index >= num_images:
            raise RuntimeError(f"Index {index} out of range 0..{num_images-1}")

        image_size = rows * cols
        f.seek(16 + index * image_size)
        pixels = list(f.read(image_size))

        if len(pixels) != 784:
            raise RuntimeError(f"Expected 784 pixels, got {len(pixels)}")

        return pixels


def read_mnist_label(labels_gz_path, index):
    with gzip.open(labels_gz_path, "rb") as f:
        magic, num_labels = struct.unpack(">II", f.read(8))

        if magic != 2049:
            raise RuntimeError(f"Invalid label magic number: {magic}")
        if index < 0 or index >= num_labels:
            raise RuntimeError(f"Index {index} out of range 0..{num_labels-1}")

        f.seek(8 + index)
        label = f.read(1)[0]

        return label


def q8_8_hex_from_pixel(pixel_0_255):
    # MNIST pixel: 0..255
    # Model input assumed normalized to 0..1.
    # Q8.8: 1.0 = 0x0100 = 256.
    q = int(round((pixel_0_255 / 255.0) * 256.0))

    if q < 0:
        q = 0
    elif q > 32767:
        q = 32767

    return f"{q & 0xFFFF:04x}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--cache-dir", default="mnist_raw")
    parser.add_argument("--out-hex", default="generated_hex/mnist_sample_hex.txt")
    parser.add_argument("--out-label", default="generated_hex/mnist_sample_label.txt")
    args = parser.parse_args()

    os.makedirs(args.cache_dir, exist_ok=True)
    os.makedirs(os.path.dirname(args.out_hex), exist_ok=True)

    images_gz = os.path.join(args.cache_dir, "t10k-images-idx3-ubyte.gz")
    labels_gz = os.path.join(args.cache_dir, "t10k-labels-idx1-ubyte.gz")

    download_if_missing(MNIST_IMAGES_URL, images_gz)
    download_if_missing(MNIST_LABELS_URL, labels_gz)

    pixels = read_mnist_image(images_gz, args.index)
    label = read_mnist_label(labels_gz, args.index)

    with open(args.out_hex, "w") as f:
        for p in pixels:
            f.write(q8_8_hex_from_pixel(p) + "\n")

    with open(args.out_label, "w") as f:
        f.write(str(label) + "\n")

    print(f"[OK] wrote image hex : {args.out_hex}")
    print(f"[OK] wrote label     : {args.out_label}")
    print(f"[INFO] MNIST index   : {args.index}")
    print(f"[INFO] true label    : {label}")


if __name__ == "__main__":
    main()
