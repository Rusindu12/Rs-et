"""
Train a SentencePiece BPE tokenizer for RS-GPT.

Demo (small corpus):
    python tokenizer_train.py --input data/sample_corpus.txt \
        --vocab-size 1600 --model-prefix tokenizer/rs_sp

Production (1B model — use a large Sinhala+English corpus, several GB):
    python tokenizer_train.py --input data/big_corpus.txt \
        --vocab-size 32000 --model-prefix tokenizer/rs_sp_32k
"""

import argparse

import sentencepiece as spm

CHAT_TOKENS = ["<|user|>", "<|assistant|>", "<|end|>"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="training text file (UTF-8)")
    ap.add_argument("--vocab-size", type=int, default=32000)
    ap.add_argument("--model-prefix", default="tokenizer/rs_sp")
    ap.add_argument("--model-type", default="bpe", choices=["bpe", "unigram"])
    ap.add_argument("--character-coverage", type=float, default=1.0,
                    help="1.0 keeps full Sinhala Unicode coverage")
    args = ap.parse_args()

    spm.SentencePieceTrainer.train(
        input=args.input,
        model_prefix=args.model_prefix,
        vocab_size=args.vocab_size,
        model_type=args.model_type,
        character_coverage=args.character_coverage,
        byte_fallback=True,                      # never OOV — unseen text -> byte pieces
        user_defined_symbols=CHAT_TOKENS,        # chat template tokens
        split_digits=True,
        allow_whitespace_only_pieces=True,
        remove_extra_whitespaces=False,
        normalization_rule_name="nfkc",
        input_sentence_size=2_000_000,
        shuffle_input_sentence=True,
    )
    print(f"[done] wrote {args.model_prefix}.model / .vocab")


if __name__ == "__main__":
    main()
