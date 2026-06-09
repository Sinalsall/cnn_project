#!/usr/bin/env python3
import argparse
import os
import re
from functools import reduce
from operator import mul


LAYER_MAP = {
    "block_1.0.weight": "conv1_weights_hex.txt",
    "block_1.0.bias":   "conv1_bias_hex.txt",

    "block_1.2.weight": "conv2_weights_hex.txt",
    "block_1.2.bias":   "conv2_bias_hex.txt",

    "block_2.0.weight": "conv3_weights_hex.txt",
    "block_2.0.bias":   "conv3_bias_hex.txt",

    "block_2.2.weight": "conv4_weights_hex.txt",
    "block_2.2.bias":   "conv4_bias_hex.txt",

    "classifier.1.weight": "fc_weights_hex.txt",
    "classifier.1.bias":   "fc_bias_hex.txt",
}


EXPECTED_COUNTS = {
    "conv1_weights_hex.txt": 90,
    "conv1_bias_hex.txt": 10,

    "conv2_weights_hex.txt": 900,
    "conv2_bias_hex.txt": 10,

    "conv3_weights_hex.txt": 900,
    "conv3_bias_hex.txt": 10,

    "conv4_weights_hex.txt": 900,
    "conv4_bias_hex.txt": 10,

    "fc_weights_hex.txt": 4900,
    "fc_bias_hex.txt": 10,
}


def prod(values):
    result = 1
    for value in values:
        result *= value
    return result


def float_to_int16_hex(value, scale):
    q = int(round(value * scale))

    if q < -32768:
        q = -32768
    elif q > 32767:
        q = 32767

    return f"{q & 0xFFFF:04x}"


def parse_apic_file(text):
    """
    Parse blocks like:

    Layer: block_1.0.weight
    Shape: [10, 1, 3, 3]
    Values: tensor([...])

    Returns:
      dict[layer_name] = (shape_list, values_float_list)
    """

    pattern = re.compile(
        r"Layer:\s*(.*?)\n"
        r"Shape:\s*\[(.*?)\]\n"
        r"Values:\s*tensor\((.*?)(?=\n\nLayer:|\Z)",
        re.S
    )

    layers = {}

    for match in pattern.finditer(text):
        layer_name = match.group(1).strip()
        shape_str = match.group(2).strip()
        body = match.group(3)

        shape = [int(x.strip()) for x in shape_str.split(",") if x.strip()]

        numbers = re.findall(
            r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:e[-+]?\d+)?",
            body,
            flags=re.I
        )
        values = [float(x) for x in numbers]

        layers[layer_name] = (shape, values)

    return layers


def write_hex_file(values, output_path, scale):
    with open(output_path, "w") as f:
        for value in values:
            f.write(float_to_int16_hex(value, scale) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        required=True,
        help="Path to APIC-EL4012 text file"
    )
    parser.add_argument(
        "--outdir",
        default="generated_hex",
        help="Output directory for generated hex files"
    )
    parser.add_argument(
        "--scale",
        type=float,
        default=256.0,
        help="Fixed-point scale. Default 256 for Q8.8"
    )

    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    with open(args.input, "r") as f:
        text = f.read()

    layers = parse_apic_file(text)

    print("=== APIC to HEX converter ===")
    print(f"Input file : {args.input}")
    print(f"Output dir : {args.outdir}")
    print(f"Scale      : {args.scale}")
    print("")

    missing_layers = []

    for layer_name, output_filename in LAYER_MAP.items():
        if layer_name not in layers:
            missing_layers.append(layer_name)
            continue

        shape, values = layers[layer_name]
        expected_from_shape = prod(shape)

        if len(values) != expected_from_shape:
            raise RuntimeError(
                f"Layer {layer_name}: parsed {len(values)} values, "
                f"but shape {shape} expects {expected_from_shape}"
            )

        expected_count = EXPECTED_COUNTS[output_filename]
        if len(values) != expected_count:
            raise RuntimeError(
                f"Layer {layer_name}: parsed {len(values)} values, "
                f"but {output_filename} expects {expected_count}"
            )

        output_path = os.path.join(args.outdir, output_filename)
        write_hex_file(values, output_path, args.scale)

        print(
            f"[OK] {layer_name:20s} shape={str(shape):18s} "
            f"count={len(values):5d} -> {output_path}"
        )

    if missing_layers:
        print("")
        print("[ERROR] Missing layers:")
        for layer_name in missing_layers:
            print(f"  - {layer_name}")
        raise SystemExit(1)

    print("")
    print("[DONE] All hex files generated successfully.")


if __name__ == "__main__":
    main()
