#!/usr/bin/env python3
"""Builds the natural voice's pronunciation files from misaki (Apache-2.0).

Reads misaki's US dictionaries (us_gold.json, us_silver.json) and Kokoro's phoneme
vocabulary (tokenizer.json), and writes:
  SooFunny/Voice/Resources/kokoro_lexicon.tsv  word<TAB>phonemes, gold entries win
  SooFunny/Voice/Resources/kokoro_vocab.tsv    phoneme<TAB>token id

Usage: python3 scripts/build_voice_lexicon.py <dir with us_gold.json us_silver.json tokenizer.json>
"""
import json, os, sys

src = sys.argv[1]
out = os.path.join(os.path.dirname(__file__), "..", "SooFunny", "Voice", "Resources")
vocab = json.load(open(os.path.join(src, "tokenizer.json")))["model"]["vocab"]

def value(v):
    # The app has no part-of-speech tagger, so it uses each word's default reading.
    return v["DEFAULT"] if isinstance(v, dict) else v

lexicon = {}
for name in ("us_silver.json", "us_gold.json"):  # gold last, so it wins
    for word, v in json.load(open(os.path.join(src, name))).items():
        p = value(v)
        if p and "\t" not in word and "\n" not in word and all(c in vocab for c in p):
            lexicon[word] = p

with open(os.path.join(out, "kokoro_lexicon.tsv"), "w", encoding="utf-8") as f:
    for word in sorted(lexicon):
        f.write(f"{word}\t{lexicon[word]}\n")
with open(os.path.join(out, "kokoro_vocab.tsv"), "w", encoding="utf-8") as f:
    for phoneme, token in sorted(vocab.items(), key=lambda kv: kv[1]):
        f.write(f"{phoneme}\t{token}\n")
print(f"{len(lexicon)} words, {len(vocab)} phonemes")
