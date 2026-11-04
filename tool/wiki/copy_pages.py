"""Copy maintained Wiki pages without removing community-authored pages."""

import shutil
import sys
from pathlib import Path


def copy_pages(source: Path, destination: Path) -> None:
    pages = sorted(source.glob('*.md'))
    if not pages or not (source / 'Home.md').is_file():
        raise ValueError('Wiki source must contain Home.md')
    for page in pages:
        shutil.copyfile(page, destination / page.name)


if __name__ == '__main__':
    copy_pages(Path(sys.argv[1]), Path(sys.argv[2]))
