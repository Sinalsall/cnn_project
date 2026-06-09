#!/usr/bin/env python3
import argparse
import os


ASCII_RAMP = " .:-=+*#%@"


def q8_8_hex_to_pixel(line):
    value = int(line.strip(), 16)
    if value >= 0x8000:
        value -= 0x10000

    pixel = round((value / 256.0) * 255.0)
    if pixel < 0:
        return 0
    if pixel > 255:
        return 255
    return pixel


def load_hex_image(path):
    with open(path, "r") as f:
        pixels = [q8_8_hex_to_pixel(line) for line in f if line.strip()]

    if len(pixels) != 28 * 28:
        raise RuntimeError(f"Expected 784 pixels in {path}, got {len(pixels)}")

    return pixels


def write_pgm(path, pixels):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"P5\n28 28\n255\n")
        f.write(bytes(pixels))


def ascii_preview(pixels):
    rows = []
    for y in range(28):
        chars = []
        for x in range(28):
            p = pixels[y * 28 + x]
            idx = round((p / 255.0) * (len(ASCII_RAMP) - 1))
            chars.append(ASCII_RAMP[idx])
        rows.append("".join(chars))
    return "\n".join(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hex", default="generated_hex/mnist_sample_hex.txt")
    parser.add_argument("--label", default="generated_hex/mnist_sample_label.txt")
    parser.add_argument("--out-pgm", default="generated_hex/mnist_sample_preview.pgm")
    parser.add_argument("--out-ascii", default="generated_hex/mnist_sample_preview.txt")
    args = parser.parse_args()

    pixels = load_hex_image(args.hex)
    write_pgm(args.out_pgm, pixels)

    preview = ascii_preview(pixels)
    with open(args.out_ascii, "w") as f:
        f.write(preview)
        f.write("\n")

    label = "unknown"
    if os.path.exists(args.label):
        with open(args.label, "r") as f:
            label = f.read().strip()

    print(f"[INFO] true label      : {label}")
    print(f"[OK] preview image    : {args.out_pgm}")
    print(f"[OK] ascii preview    : {args.out_ascii}")
    print("")
    print(preview)


if __name__ == "__main__":
    main()
