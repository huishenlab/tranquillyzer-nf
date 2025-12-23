#!/usr/bin/env python3
import os
import re
import shlex
import glob
import subprocess
import logging
from typing import Dict, List, Tuple

import typer

app = typer.Typer(add_completion=False)


logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def eprint(*args, **kwargs):
    typer.echo(" ".join(str(a) for a in args), err=True)


def natural_key(s: str):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]


def find_bams(bam_dir: str) -> List[str]:
    return sorted(glob.glob(os.path.join(bam_dir, "*.bam")), key=natural_key)


def run_featurecounts_batch(
    featurecounts: str,
    gtf: str,
    out_txt: str,
    bam_paths: List[str],
    threads: int,
    extra_args: List[str],
    retry_threads: List[int] = None,
    bisect_on_fail: bool = True,
    min_batch_size: int = 1,
) -> None:
    """
    Run featureCounts on a list of BAMs.
    If featureCounts crashes, retry with fewer threads; optionally bisect to isolate bad BAMs.
    """
    os.makedirs(os.path.dirname(out_txt), exist_ok=True)

    if retry_threads is None:
        # Try the requested threads first, then progressively smaller.
        # (Don’t go above requested threads.)
        retry_threads = [threads, 16, 8, 4, 1]
        retry_threads = [t for t in retry_threads if t <= threads]
        retry_threads = list(
            dict.fromkeys(retry_threads)
        )  # unique preserve order

    def _run_once(
        t: int, out_path: str, bams: List[str]
    ) -> subprocess.CompletedProcess:
        cmd = (
            [featurecounts, "-a", gtf, "-o", out_path, "-T", str(t)]
            + extra_args
            + bams
        )
        logger.info(
            "Running featureCounts: %s", " ".join(shlex.quote(x) for x in cmd)
        )
        return subprocess.run(cmd)

    # Try a sequence of thread counts
    for t in retry_threads:
        proc = _run_once(t, out_txt, bam_paths)
        if proc.returncode == 0:
            logger.info(
                "featureCounts succeeded: out=%s (threads=%d, bams=%d)",
                out_txt,
                t,
                len(bam_paths),
            )
            return

        logger.error(
            "featureCounts failed (rc=%d) out=%s threads=%d bams=%d",
            proc.returncode,
            out_txt,
            t,
            len(bam_paths),
        )

    # If we get here, all thread-retries failed.
    if not bisect_on_fail or len(bam_paths) <= min_batch_size:
        raise subprocess.CalledProcessError(
            returncode=proc.returncode,
            cmd=[
                featurecounts,
                "-a",
                gtf,
                "-o",
                out_txt,
                "-T",
                str(retry_threads[-1]),
            ]
            + extra_args
            + bam_paths,
        )

    # Bisect: split into halves and run recursively, producing two outputs then merge later
    mid = len(bam_paths) // 2
    left = bam_paths[:mid]
    right = bam_paths[mid:]

    left_out = out_txt.replace(".txt", ".left.txt")
    right_out = out_txt.replace(".txt", ".right.txt")

    logger.warning(
        "Bisecting batch due to repeated failure: %s -> (%d, %d)",
        out_txt,
        len(left),
        len(right),
    )

    run_featurecounts_batch(
        featurecounts=featurecounts,
        gtf=gtf,
        out_txt=left_out,
        bam_paths=left,
        threads=threads,
        extra_args=extra_args,
        retry_threads=retry_threads,
        bisect_on_fail=bisect_on_fail,
        min_batch_size=min_batch_size,
    )
    run_featurecounts_batch(
        featurecounts=featurecounts,
        gtf=gtf,
        out_txt=right_out,
        bam_paths=right,
        threads=threads,
        extra_args=extra_args,
        retry_threads=retry_threads,
        bisect_on_fail=bisect_on_fail,
        min_batch_size=min_batch_size,
    )

    # Mark the parent batch as “handled by bisection”
    with open(out_txt + ".BISected", "w") as f:
        f.write("This batch was bisected into:\n")
        f.write(left_out + "\n")
        f.write(right_out + "\n")

    logger.info("Bisect outputs written: %s, %s", left_out, right_out)
    return


def parse_featurecounts_counts(
    path: str,
) -> Tuple[List[str], Dict[str, List[str]]]:
    sample_names: List[str] = []
    counts_by_gene: Dict[str, List[str]] = {}

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue

            if line.startswith("Geneid\t"):
                cols = line.rstrip("\n").split("\t")
                if len(cols) < 7:
                    raise ValueError(
                        f"Unexpected featureCounts header in {path}"
                    )
                sample_names = cols[6:]
                continue

            cols = line.rstrip("\n").split("\t")
            gene = cols[0]
            counts = cols[6:]
            if sample_names and len(counts) != len(sample_names):
                raise ValueError(
                    f"Sample column mismatch in {path} for gene {gene}"
                )
            counts_by_gene[gene] = counts

    if not sample_names:
        raise ValueError(f"Did not find header in featureCounts file: {path}")

    return sample_names, counts_by_gene


def write_matrix(
    out_matrix: str,
    gene_order: List[str],
    all_samples: List[str],
    merged_counts: Dict[str, List[str]],
) -> None:
    os.makedirs(os.path.dirname(out_matrix), exist_ok=True)
    with open(out_matrix, "w", encoding="utf-8") as out:
        out.write("Geneid\t" + "\t".join(all_samples) + "\n")
        for g in gene_order:
            out.write(g + "\t" + "\t".join(merged_counts[g]) + "\n")


@app.command(no_args_is_help=True)
def featurecounts_matrix(
    bam_dir: str = typer.Option(
        ...,
        "--bam-dir",
        help="Directory containing per-CB BAM files (*.bam).",
    ),
    gtf: str = typer.Option(
        ...,
        "--gtf",
        help="Annotation file for featureCounts (-a), typically a GTF.",
    ),
    out_dir: str = typer.Option(
        ...,
        "--out-dir",
        "-o",
        help="Output directory for batch results and final matrix.",
    ),
    featurecounts: str = typer.Option(
        "featureCounts",
        "--featurecounts",
        help="Path to featureCounts executable.",
    ),
    batch_size: int = typer.Option(
        200,
        "--batch-size",
        help="Number of BAMs per featureCounts call (keeps command lines manageable).",
        min=1,
    ),
    threads: int = typer.Option(
        8,
        "--threads",
        "-t",
        help="Threads per featureCounts call (-T). For shared filesystems, 4–16 is usually best.",
        min=1,
    ),
    extra: str = typer.Option(
        # Long-read defaults: gene-level exon counting, single-end, allow split alignments
        "-t exon -g gene_id -O",
        "--extra",
        help=(
            "Extra args passed to featureCounts (string). Long-read-friendly default: "
            "'-t exon -g gene_id -O'. "
            "Add strandness with '-s 1' or '-s 2' if needed. "
            "Avoid paired-end flags (-p/-B/-C) for long reads."
        ),
    ),
    matrix_name: str = typer.Option(
        "counts_matrix.tsv",
        "--matrix-name",
        help="Filename for the final merged counts matrix (TSV).",
    ),
    no_run: bool = typer.Option(
        False,
        "--no-run",
        help="Skip running featureCounts; only merge existing batch outputs in <out_dir>/batches.",
    ),
):
    """
    Run featureCounts over many BAMs (batches) and merge outputs into a gene×cell matrix.

    Notes for long-read scRNA-seq:
      - Typically treat alignments as single-end (no -p).
      - If your BAM is already deduped/duplicate-marked per UMI/molecule, counts are closer to molecules.
      - Consider strandness (-s 1/-s 2) depending on library prep.
    """
    if not os.path.isdir(bam_dir):
        raise typer.BadParameter(f"--bam-dir is not a directory: {bam_dir}")
    if not os.path.exists(gtf):
        raise typer.BadParameter(f"--gtf not found: {gtf}")

    os.makedirs(out_dir, exist_ok=True)
    batches_dir = os.path.join(out_dir, "batches")
    os.makedirs(batches_dir, exist_ok=True)

    bams = find_bams(bam_dir)
    if not bams:
        raise typer.BadParameter(f"No BAMs found in: {bam_dir}")

    eprint(f"[info] BAMs found: {len(bams)}")

    extra_args = shlex.split(extra)

    batch_outputs: List[str] = []
    if not no_run:
        for i in range(0, len(bams), batch_size):
            chunk = bams[i : i + batch_size]
            batch_idx = i // batch_size
            out_txt = os.path.join(
                batches_dir, f"featurecounts_batch{batch_idx:04d}.txt"
            )
            batch_outputs.append(out_txt)

            if os.path.exists(out_txt) and os.path.getsize(out_txt) > 0:
                eprint(f"[skip] exists: {out_txt}")
                continue

            run_featurecounts_batch(
                featurecounts=featurecounts,
                gtf=gtf,
                out_txt=out_txt,
                bam_paths=chunk,
                threads=threads,
                extra_args=extra_args,
            )
    else:
        batch_outputs = sorted(
            glob.glob(os.path.join(batches_dir, "featurecounts_batch*.txt")),
            key=natural_key,
        )
        if not batch_outputs:
            raise typer.BadParameter(
                f"--no-run specified but no batch outputs found in: {batches_dir}"
            )

    eprint(f"[info] Batch outputs to merge: {len(batch_outputs)}")

    # Merge batches
    all_samples: List[str] = []
    gene_order: List[str] = []
    merged_counts: Dict[str, List[str]] = {}
    first = True

    for path in batch_outputs:
        samples, counts_by_gene = parse_featurecounts_counts(path)
        samples_norm = [
            os.path.splitext(os.path.basename(s))[0] for s in samples
        ]

        if first:
            all_samples.extend(samples_norm)
            gene_order = list(counts_by_gene.keys())
            for g in gene_order:
                merged_counts[g] = counts_by_gene[g]
            first = False
        else:
            start_col = len(all_samples)
            all_samples.extend(samples_norm)

            for g in gene_order:
                prev = merged_counts[g]
                add = counts_by_gene.get(g)
                if add is None:
                    prev.extend(["0"] * len(samples_norm))
                else:
                    prev.extend(add)

            # Add any new genes (rare)
            for g in counts_by_gene.keys():
                if g not in merged_counts:
                    merged_counts[g] = (["0"] * start_col) + counts_by_gene[g]
                    gene_order.append(g)

    out_matrix = os.path.join(out_dir, matrix_name)
    write_matrix(out_matrix, gene_order, all_samples, merged_counts)

    eprint(f"[done] Wrote matrix: {out_matrix}")
    eprint(f"[done] Shape: genes={len(gene_order)} cells={len(all_samples)}")


if __name__ == "__main__":
    app()
