#!/usr/bin/env python3
"""Initialize developer-only inputs for the SEG replication-clean directory.

This internal helper copies selected input files and folders from the original
developer data tree at ``~/iec/seg`` into ``~/iec/seg-replication-clean`` while
preserving paths relative to the source root. It is intended for DDL/IEC
developer setup work only and is not part of the public replication package.

The input list below is intentionally configurable and should be populated from
the lineage of ``a/make_seg_results.do`` before using this for a full setup.

Example usage:

    # Preview what would be copied
    python b/init_replication_inputs.py --dry-run

    # Run the copy
    python b/init_replication_inputs.py

    # Overwrite existing files at destination
    python b/init_replication_inputs.py --overwrite
"""

import argparse
import logging
import shutil
import sys
from pathlib import Path


DEFAULT_SOURCE = Path.home() / "iec" / "seg"
DEFAULT_DEST = Path.home() / "iec" / "seg-replication-clean"

# TODO: Populate this list from the input-file lineage of a/make_seg_results.do.
# Paths must be relative to DEFAULT_SOURCE / --source.
INPUT_FILES: tuple[str, ...] = ()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Copy required SEG replication inputs from the original developer "
            "data directory into the clean replication directory."
        )
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"Source root directory. Defaults to {DEFAULT_SOURCE}.",
    )
    parser.add_argument(
        "--dest",
        type=Path,
        default=DEFAULT_DEST,
        help=f"Destination root directory. Defaults to {DEFAULT_DEST}.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions that would be taken without copying files.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite destination files that already exist.",
    )
    return parser.parse_args()


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s: %(message)s",
    )


def normalize_relative_path(path_text: str) -> Path:
    relative_path = Path(path_text)
    if relative_path.is_absolute() or ".." in relative_path.parts:
        raise ValueError(f"Input path must be relative to the source root: {path_text}")
    return relative_path


def ensure_dest_root(dest_root: Path, dry_run: bool) -> None:
    if dest_root.exists():
        return
    if dry_run:
        logging.info("Would create destination directory: %s", dest_root)
        return
    dest_root.mkdir(parents=True, exist_ok=True)
    logging.info("Created destination directory: %s", dest_root)


def copy_file(source_file: Path, dest_file: Path, overwrite: bool, dry_run: bool) -> None:
    dest_exists = dest_file.exists()
    if dest_exists and not overwrite:
        logging.info("Skipped existing file: %s", dest_file)
        return

    if dry_run:
        action = "overwrite" if dest_exists else "copy"
        logging.info("Would %s file: %s -> %s", action, source_file, dest_file)
        return

    dest_file.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_file, dest_file)
    action = "Overwrote" if dest_exists else "Copied"
    logging.info("%s file: %s -> %s", action, source_file, dest_file)


def iter_files(source_path: Path) -> list[Path]:
    if source_path.is_file():
        return [source_path]
    return sorted(path for path in source_path.rglob("*") if path.is_file())


def copy_input_path(
    relative_path: Path,
    source_root: Path,
    dest_root: Path,
    overwrite: bool,
    dry_run: bool,
) -> bool:
    source_path = source_root / relative_path
    dest_path = dest_root / relative_path

    if not source_path.exists():
        logging.warning("Missing required input: %s", source_path)
        return False

    if source_path.is_dir():
        logging.info("Processing directory: %s", source_path)
        for source_file in iter_files(source_path):
            nested_relative_path = source_file.relative_to(source_root)
            copy_file(
                source_file,
                dest_root / nested_relative_path,
                overwrite=overwrite,
                dry_run=dry_run,
            )
        return True

    copy_file(source_path, dest_path, overwrite=overwrite, dry_run=dry_run)
    return True


def main() -> int:
    configure_logging()
    args = parse_args()
    source_root = args.source.expanduser().resolve()
    dest_root = args.dest.expanduser().resolve()

    logging.info("Source root: %s", source_root)
    logging.info("Destination root: %s", dest_root)

    if not INPUT_FILES:
        logging.warning(
            "No inputs configured. Populate INPUT_FILES from a/make_seg_results.do lineage."
        )
        return 0

    ensure_dest_root(dest_root, dry_run=args.dry_run)

    missing_inputs: list[Path] = []
    for path_text in INPUT_FILES:
        try:
            relative_path = normalize_relative_path(path_text)
        except ValueError as error:
            logging.warning("%s", error)
            missing_inputs.append(Path(path_text))
            continue

        copied_or_present = copy_input_path(
            relative_path,
            source_root=source_root,
            dest_root=dest_root,
            overwrite=args.overwrite,
            dry_run=args.dry_run,
        )
        if not copied_or_present:
            missing_inputs.append(relative_path)

    if missing_inputs:
        logging.error("Missing required inputs: %d", len(missing_inputs))
        for missing_input in missing_inputs:
            logging.error("Missing: %s", missing_input)
        return 1

    logging.info("Replication input initialization completed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
