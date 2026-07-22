#!/usr/bin/env bash
# generate_doc_pdfs.sh -- Render project docs to PDF via pandoc.
#
# In scope: everything under docs/ (recursive), plus root README.md,
# PROJECT_STATUS.md, CHANGELOG.md. Out of scope: pub/ (already has its own
# marp/pandoc pipeline for the progress slides) and the scattered small
# READMEs under config/overrides/, data/tables/, scripts/sql/**,
# tests/fixtures/sample_data/ -- those are inline code-adjacent notes, not
# standalone deliverables.
#
# Output mirrors the source tree under docs/pdf/, e.g.
#   docs/format_specifications/standard_format.md
#     -> docs/pdf/format_specifications/standard_format.pdf
#   README.md -> docs/pdf/README.pdf
#
# Usage:
#   scripts/docs/generate_doc_pdfs.sh

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out_root="$repo_root/docs/pdf"

if ! command -v pandoc >/dev/null 2>&1; then
    echo "pandoc not found on PATH -- install it first (e.g. 'brew install pandoc')." >&2
    exit 1
fi

pdf_engine=""
for engine in xelatex lualatex pdflatex; do
    if command -v "$engine" >/dev/null 2>&1; then
        pdf_engine="$engine"
        break
    fi
done
if [ -z "$pdf_engine" ]; then
    echo "No LaTeX PDF engine found (xelatex/lualatex/pdflatex) -- install a TeX distribution (e.g. BasicTeX)." >&2
    exit 1
fi

# xelatex/lualatex only: pick body/monospace fonts with full glyph coverage
# for the box-drawing characters (repo-structure trees) and math symbols
# (≤, ≥, °, etc.) used throughout these docs -- the default Latin Modern
# fonts render both as blank boxes. pdflatex ignores -V mainfont/monofont
# (no fontspec support), so this only takes effect for xelatex/lualatex.
font_args=(-V mainfont="Arial Unicode MS" -V monofont="Menlo")

mkdir -p "$out_root"

render() {
    # $1 = source .md file, $2 = base dir that dest paths are relative to
    # (repo_root for root-level docs, repo_root/docs for everything else --
    # keeps docs/pdf/ mirroring docs/'s own internal structure, not
    # docs/pdf/docs/...).
    local src="$1"
    local base="$2"
    local rel="${src#"$base"/}"
    local rel_noext="${rel%.md}"
    local dest="$out_root/${rel_noext}.pdf"
    mkdir -p "$(dirname "$dest")"
    echo "Rendering ${src#"$repo_root"/} -> ${dest#"$repo_root"/}"
    pandoc "$src" -o "$dest" --pdf-engine="$pdf_engine" "${font_args[@]}"
}

# Root-level docs
for f in README.md PROJECT_STATUS.md CHANGELOG.md; do
    if [ -f "$repo_root/$f" ]; then
        render "$repo_root/$f" "$repo_root"
    fi
done

# Everything under docs/, recursively, excluding docs/pdf/ itself
while IFS= read -r -d '' f; do
    render "$f" "$repo_root/docs"
done < <(find "$repo_root/docs" -name '*.md' -not -path "$out_root/*" -print0)

echo "Done. Output under: ${out_root#"$repo_root"/}"
