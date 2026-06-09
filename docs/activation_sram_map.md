# Activation SRAM Map

This is the planned memory map for replacing the large internal activation
arrays in `cnn_top_multichannel_serial.v`.

Each address is a 16-bit activation word. The physical implementation is
`16 banks x 1024 words x 16-bit`.

## Candidate Regions

| Region | Base | Words | Purpose |
|---|---:|---:|---|
| `IMG` | 0 | 784 | Input image, 1x28x28 |
| `BUF_A` | 0 | 7840 | Ping-pong full-size buffer A |
| `BUF_B` | 8192 | 7840 | Ping-pong full-size buffer B |

`BUF_A` and `BUF_B` intentionally overlap `IMG` because the input image can
be treated as the first source buffer. During refactor, the FSM should avoid
overwriting source data before the consuming layer is finished.

## Layer Shapes

| Tensor | Words |
|---|---:|
| Input image `1x28x28` | 784 |
| Conv/ReLU output `10x28x28` | 7840 |
| Pool output `10x14x14` | 1960 |
| Final pool output `10x7x7` | 490 |

## Next Refactor Target

Move `image_mem`, `act1_mem`, `act2_mem`, `pool1_mem`, `act3_mem`,
`act4_mem`, and `pool2_mem` access into scheduled reads/writes against
`cnn_activation_sram_bank`.
