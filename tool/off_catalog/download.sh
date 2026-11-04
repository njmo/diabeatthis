#!/bin/sh
set -eu
catalog_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$catalog_dir/data"
curl --fail --location --retry 3 \
  --dump-header "$catalog_dir/data/download-headers.txt" \
  --output "$catalog_dir/data/products.tsv.gz.partial" \
  'https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz'
gzip -t "$catalog_dir/data/products.tsv.gz.partial"
mv "$catalog_dir/data/products.tsv.gz.partial" "$catalog_dir/data/products.tsv.gz"
