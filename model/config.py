"""Predefined model sizes for RS-GPT."""

from gpt import GPTConfig

# Parameter counts (approx., vocab=32000 unless noted):
CONFIGS = {
    # ---- The headline model: ~1.0B parameters ----
    # emb: 32000*2048 = 65.5M | per layer: 4*d^2 + 3*d*ff = 16.8M + 33.8M = 50.6M
    # 18 layers = 910M  ->  total ~= 976M params (tied LM head)
    "rs-gpt-1b": GPTConfig(
        vocab_size=32000, block_size=2048,
        n_layer=18, n_head=16, d_model=2048, d_ff=5504,
        dropout=0.0,
    ),
    # Alternative ~1.25B variant
    "rs-gpt-1.2b": GPTConfig(
        vocab_size=32000, block_size=2048,
        n_layer=20, n_head=16, d_model=2048, d_ff=5504,
        dropout=0.0,
    ),
    # ---- ~3.95B ("4B class") model ----
    # emb: 32000*3072 = 98.3M | per layer: 4*d^2 + 3*d*ff = 37.7M + 75.5M = 113.2M
    # 34 layers = 3.85B  ->  total ~= 3.95B params (tied LM head)
    # Training needs serious GPU power — see README (H100/A100-80GB + grad ckpt).
    "rs-gpt-4b": GPTConfig(
        vocab_size=32000, block_size=2048,
        n_layer=34, n_head=24, d_model=3072, d_ff=8192,
        dropout=0.0,
    ),
    # Small model for quick experiments on a single GPU (e.g. Colab T4)
    "rs-gpt-60m": GPTConfig(
        vocab_size=32000, block_size=1024,
        n_layer=8, n_head=8, d_model=512, d_ff=1408,
        dropout=0.0,
    ),
    # CPU demo model used for the in-sandbox pipeline proof (vocab 1600)
    "rs-gpt-demo": GPTConfig(
        vocab_size=1600, block_size=128,
        n_layer=4, n_head=4, d_model=256, d_ff=704,
        dropout=0.1,
    ),
}
