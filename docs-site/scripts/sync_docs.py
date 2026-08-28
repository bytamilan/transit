#!/usr/bin/env python3
"""Copies source-of-truth docs into docs-site/docs/ at build time.

Everything under docs/packages/ and docs/wiki/ is generated from
packages/*/README.md and internal-docs/** respectively — never edit those
two directories directly, edit the source and re-run this script (or
`make docs`/`make docs-serve`, which run it automatically).
"""
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs-site" / "docs"


def reset(target: Path) -> None:
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)


def sync_wiki() -> None:
    wiki = DOCS / "wiki"
    reset(wiki)

    adr_dst = wiki / "adr"
    adr_dst.mkdir(parents=True)
    for f in sorted((ROOT / "internal-docs" / "adr").glob("*.md")):
        shutil.copyfile(f, adr_dst / f.name)

    shutil.copyfile(
        ROOT / "internal-docs" / "onboarding" / "README.md", wiki / "onboarding.md"
    )

    runbooks_dst = wiki / "runbooks"
    runbooks_dst.mkdir(parents=True)
    for f in sorted((ROOT / "internal-docs" / "runbooks").glob("*.md")):
        shutil.copyfile(f, runbooks_dst / f.name)


def sync_packages() -> None:
    packages_dst = DOCS / "packages"
    reset(packages_dst)

    for pkg_dir in sorted((ROOT / "packages").iterdir()):
        readme = pkg_dir / "README.md"
        if not readme.is_file():
            continue
        text = readme.read_text()
        if not text.lstrip().startswith("#"):
            text = f"# {pkg_dir.name}\n\n{text}"
        if pkg_dir.name == "transit_api_client":
            text += (
                "\n\n!!! note\n"
                "    This package's generated client docs "
                "(`packages/transit_api_client/doc/*.md`) mirror "
                "`contracts/openapi.yaml` method-by-method — see the "
                "[API Reference](../api/index.html) for the browsable version "
                "instead of reading the generated markdown directly.\n"
            )
        (packages_dst / f"{pkg_dir.name}.md").write_text(text)


if __name__ == "__main__":
    sync_wiki()
    sync_packages()
    print("Synced internal-docs/ and packages/*/README.md into docs-site/docs/")
