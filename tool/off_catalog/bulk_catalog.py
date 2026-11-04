#!/usr/bin/env python3
"""Download complete configured manufacturer catalogs, then match locally."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import hashlib
from pathlib import Path
import xml.etree.ElementTree as ET

from common.catalog_http import CatalogHttp
from common.catalog_parsers import parse_mlekovita, parse_piatnica
from common.catalog_additional_parsers import parse_sante, parse_lowicz

ROOT = Path(__file__).resolve().parent
SOURCES = {
    'sante': {'base':'https://sante.pl','sitemap':'https://sante.pl/sante-produkty-sitemap.xml','product_path':'/produkty/','parser':parse_sante},
    'lowicz': {'base':'https://mleczarnia.lowicz.pl','sitemap':'https://mleczarnia.lowicz.pl/wp-sitemap.xml','product_path':'/produkt/','parser':parse_lowicz},
    'mlekovita': {'base': 'https://mlekovita.com.pl', 'sitemap': 'https://mlekovita.com.pl/sitemap.xml', 'product_path': '/produkt/', 'parser': parse_mlekovita},
    'piatnica': {'base': 'https://piatnica.com.pl', 'sitemap': 'https://piatnica.com.pl/sitemap_index.xml', 'product_path': '/produkt/', 'parser': parse_piatnica},
}


def discover(client, url, path, seen=None):
    seen = set() if seen is None else seen
    if url in seen:
        return []
    if len(seen) >= 30:
        raise ValueError('Sitemap recursion bound reached')
    seen.add(url)
    tree = ET.fromstring(client.read(url))
    locations = [e.text.strip() for e in tree.iter() if e.tag.rsplit('}', 1)[-1] == 'loc' and e.text]
    if tree.tag.rsplit('}', 1)[-1] == 'sitemapindex':
        result = []
        # Product sitemap is explicitly identified by the publisher, skip recipes/news.
        selected = [u for u in locations if 'product' in u or 'produkt' in u]
        for child in selected or locations:
            result.extend(discover(client, child, path, seen))
        return sorted(set(result))
    if tree.tag.rsplit('}', 1)[-1] != 'urlset':
        raise ValueError('Expected XML sitemap, got another document')
    return sorted({u for u in locations if client.allowed(u) and path in u and u.rstrip('/') != (getattr(client, 'base_url', '') + path).rstrip('/') and '?' not in u})


def download(source, directory, delay=0.5, refresh=False, limit=None):
    config = SOURCES[source]
    output = directory / source
    output.mkdir(parents=True, exist_ok=True)
    client = CatalogHttp(config['base'], output / 'cache', delay=delay, refresh=refresh)
    urls = discover(client, config['sitemap'], config['product_path'])
    if not urls:
        raise ValueError('No product URLs discovered; source connector needs review')
    selected = urls if limit is None else urls[:limit]
    failures, records = [], []
    for index, url in enumerate(selected, 1):
        try:
            parsed = config['parser'](url, client.read(url))
            if not parsed:
                raise ValueError('Product page has no parseable identity')
            records.extend(parsed)
        except Exception as error:
            failures.append({'url': url, 'error_type': type(error).__name__, 'http_status': getattr(error, 'code', None)})
            if getattr(error, 'code', None) in (429, 503):
                break
        if index % 100 == 0:
            print(json.dumps({'source': source, 'downloaded': index, 'total': len(selected)}), flush=True)
    unique = {r['id']: r for r in records}
    if len(unique) != len(records):
        raise ValueError('Duplicate source catalog identities')
    temporary = output / 'catalog.jsonl.partial'
    with temporary.open('w', encoding='utf-8') as stream:
        for record in sorted(records, key=lambda r: r['source_url']):
            stream.write(json.dumps(record, ensure_ascii=False, allow_nan=False) + '\n')
    temporary.replace(output / 'catalog.jsonl')
    manifest = {'catalog_sha256': hashlib.sha256((output / 'catalog.jsonl').read_bytes()).hexdigest(), 'source': source, 'created_at': datetime.now(timezone.utc).isoformat(), 'discovered_pages': len(urls),
                'attempted_pages': index, 'parsed_products': len(records),
                'products_with_core_macros': sum(all(r['nutrition'].get(k) is not None for k in ('carbs', 'fat', 'protein')) for r in records),
                'products_without_barcode': sum(not r['barcodes'] for r in records),
                'requests': client.requests, 'cache_hits': client.cache_hits, 'failures': failures,
                'complete': index == len(urls) and not failures, 'firebase_writes': 0,
                'license': 'Manufacturer source; public access is not redistribution permission.'}
    manifest_path = output / 'manifest.json.partial'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    manifest_path.replace(output / 'manifest.json')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', nargs='+', choices=SOURCES, default=list(SOURCES))
    parser.add_argument('--directory', type=Path, default=ROOT / 'data/bulk')
    parser.add_argument('--delay', type=float, default=0.5)
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--limit', type=int, help='Optional diagnostic subset; manifest is marked incomplete')
    args = parser.parse_args()
    if args.delay < 0 or (args.limit is not None and args.limit < 1):
        parser.error('Invalid pacing or page limit')
    with ThreadPoolExecutor(max_workers=len(args.sources)) as pool:
        futures = [pool.submit(download, source, args.directory, args.delay, args.refresh, args.limit) for source in args.sources]
        for future in futures:
            print(json.dumps(future.result(), ensure_ascii=False, indent=2), flush=True)
