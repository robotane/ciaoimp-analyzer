"""Entry point: python -m src.cleaning.expand [file.pl out.pl | dir]"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from .normalize import normalize_syntax, flatten_conj, rewrite_ops
from .parser import parse_sentences, is_noise
from .transformer import Transformer


def process_file(input_path: str, output_path: str) -> None:
    with open(input_path, encoding="utf-8") as f:
        text = f.read()

    sentences = [s for s in parse_sentences(text) if not is_noise(s)]
    text = normalize_syntax("\n\n".join(sentences))

    sentences = parse_sentences(text)
    xf = Transformer()
    outputs = []
    for sent in sentences:
        s = sent.strip()
        if s.startswith(":-"):
            s = rewrite_ops(s)
            s = flatten_conj(s)
            outputs.append(s)
        else:
            outputs.append(xf.transform(s))

    result = "\n\n".join(outputs)
    if xf.helpers:
        result += "\n\n" + "\n\n".join(xf.helpers)

    result = re.sub(r"\n{3,}", "\n\n", result).strip() + "\n"

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(result)
    print(f"  OK  {os.path.basename(input_path)}")


def main() -> None:
    if len(sys.argv) == 3 and os.path.isfile(sys.argv[1]):
        process_file(sys.argv[1], sys.argv[2])
        return

    pipeline_root = Path(__file__).resolve().parents[4]
    input_dir = pipeline_root / "expanded_native"
    output_dir = pipeline_root / "final_native"
    output_dir.mkdir(parents=True, exist_ok=True)

    targets = sys.argv[1:] if len(sys.argv) > 1 else sorted(os.listdir(input_dir))
    for arg in targets:
        bn = os.path.basename(arg)
        if not bn.endswith(".pl"):
            continue
        inp = arg if os.path.isabs(arg) else str(input_dir / bn)
        out = str(output_dir / bn)
        try:
            process_file(inp, out)
        except Exception as e:
            print(f"  ERR {bn}: {e}")


if __name__ == "__main__":
    main()
