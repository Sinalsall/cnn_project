#!/usr/bin/env python3
import numpy as np


def hex_to_s16(x):
    v = int(x.strip(), 16)
    if v >= 0x8000:
        v -= 0x10000
    return v


def wrap_s16(x):
    x = int(x) & 0xFFFF
    if x >= 0x8000:
        x -= 0x10000
    return x


def load_hex(path):
    with open(path, "r") as f:
        return np.array([hex_to_s16(line) for line in f if line.strip()], dtype=np.int64)


def conv2d_same_no_rescale(x, w, b):
    # x shape: [IC, H, W]
    # w shape: [OC, IC, 3, 3]
    # b shape: [OC]
    ic, h, ww = x.shape
    oc = w.shape[0]

    y = np.zeros((oc, h, ww), dtype=np.int64)

    for o in range(oc):
        for yy in range(h):
            for xx in range(ww):
                acc = int(b[o])

                for c in range(ic):
                    for ky in range(3):
                        for kx in range(3):
                            iy = yy + ky - 1
                            ix = xx + kx - 1

                            if 0 <= iy < h and 0 <= ix < ww:
                                acc += int(x[c, iy, ix]) * int(w[o, c, ky, kx])

                y[o, yy, xx] = wrap_s16(acc)

    return y


def relu_s16(x):
    return np.maximum(x, 0).astype(np.int64)


def maxpool2x2(x):
    # x shape: [C, H, W]
    c, h, w = x.shape
    out = np.zeros((c, h // 2, w // 2), dtype=np.int64)

    for ch in range(c):
        for yy in range(h // 2):
            for xx in range(w // 2):
                block = x[ch, yy*2:yy*2+2, xx*2:xx*2+2]
                out[ch, yy, xx] = np.max(block)

    return out


def fc_no_rescale(x_flat, w, b):
    # x_flat shape: [490]
    # w shape: [10, 490]
    # b shape: [10]
    out = np.zeros(10, dtype=np.int64)

    for o in range(10):
        acc = int(b[o])
        for i in range(490):
            acc += int(x_flat[i]) * int(w[o, i])

        out[o] = wrap_s16(acc)

    return out


def main():
    conv1_w = load_hex("generated_hex/conv1_weights_hex.txt").reshape(10, 1, 3, 3)
    conv1_b = load_hex("generated_hex/conv1_bias_hex.txt")

    conv2_w = load_hex("generated_hex/conv2_weights_hex.txt").reshape(10, 10, 3, 3)
    conv2_b = load_hex("generated_hex/conv2_bias_hex.txt")

    conv3_w = load_hex("generated_hex/conv3_weights_hex.txt").reshape(10, 10, 3, 3)
    conv3_b = load_hex("generated_hex/conv3_bias_hex.txt")

    conv4_w = load_hex("generated_hex/conv4_weights_hex.txt").reshape(10, 10, 3, 3)
    conv4_b = load_hex("generated_hex/conv4_bias_hex.txt")

    fc_w = load_hex("generated_hex/fc_weights_hex.txt").reshape(10, 490)
    fc_b = load_hex("generated_hex/fc_bias_hex.txt")

    image = load_hex("generated_hex/mnist_sample_hex.txt").reshape(1, 28, 28)

    x = image

    x = conv2d_same_no_rescale(x, conv1_w, conv1_b)
    x = relu_s16(x)

    x = conv2d_same_no_rescale(x, conv2_w, conv2_b)
    x = relu_s16(x)

    x = maxpool2x2(x)

    x = conv2d_same_no_rescale(x, conv3_w, conv3_b)
    x = relu_s16(x)

    x = conv2d_same_no_rescale(x, conv4_w, conv4_b)
    x = relu_s16(x)

    x = maxpool2x2(x)

    x_flat = x.reshape(-1)

    scores = fc_no_rescale(x_flat, fc_w, fc_b)

    print("=== Golden model: current RTL-like fixed-point, no rescale ===")
    for i, s in enumerate(scores):
        print(f"class_scores[{i}] = 0x{s & 0xFFFF:04x} signed={int(s)}")

    pred = int(np.argmax(scores))
    print(f"predicted_class = {pred}, best_score = {int(scores[pred])} / 0x{scores[pred] & 0xFFFF:04x}")

    try:
        with open("generated_hex/mnist_sample_label.txt", "r") as f:
            label = f.read().strip()
        print(f"true_label = {label}")
    except FileNotFoundError:
        pass


if __name__ == "__main__":
    main()
