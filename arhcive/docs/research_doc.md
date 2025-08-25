#### Core Capabilities:

- Perform fast matrix multiplications and convolutions — the backbone of neural network computation.
- Execute element-wise arithmetic operations like addition, multiplication, and dot products.
- Apply activation functions such as ReLU, Sigmoid, Tanh to add non-linearity.
- Support pooling operations (Max Pooling, Average Pooling) for downsampling features.
- Perform normalization operations like BatchNorm and LayerNorm to stabilize training results (in some implementations).
- Handle quantization and dequantization to run models efficiently with low-precision (e.g., INT8).
- Process softmax functions for classification tasks.
- Manage data movement and buffering efficiently between memory and compute units.
- Schedule and orchestrate all these operations with a control unit and instruction decoder.
