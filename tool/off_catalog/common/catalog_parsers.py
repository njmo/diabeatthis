"""Manufacturer adapters preserve exact values, limits, physical basis and variants."""

import hashlib
import re
from .catalog_html import CatalogHtml

KEYS = ('carbs', 'fiber', 'fat', 'protein', 'energy_kcal')
LABELS = {'carbs': r'węglowodany', 'fiber': r'błonnik(?:a)?', 'fat': r'tłuszcz(?:e)?', 'protein': r'białk[oa]'}
NUMBER = r'(?:\d+(?:[.,]\d+)?)'


def exact_number(text):
    if re.search(r'[<>≤≥~]|poniżej|mniej niż|około|(?<!\w)-\s*\d|\d\s*[-–—]\s*\d', text, re.I):
        return None
    match = re.search(NUMBER, text)
    return float(match.group().replace(',', '.')) if match else None


def energy_value(text):
    pattern = r'((?:[-<>≤≥~]|poniżej|mniej niż|około)?\s*' + NUMBER + r'(?:\s*[-–—]\s*' + NUMBER + r')?)\s*kcal\b'
    match = re.search(pattern, text, re.I)
    return (exact_number(match.group(1)), match.group(0)) if match else (None, None)


def nutrition(text):
    values, evidence = dict.fromkeys(KEYS), {}
    for key, label in LABELS.items():
        match = re.search(r'\b' + label + r'\s*:?\s*([-<>≤≥~]?\s*' + NUMBER + r')\s*g\b', text, re.I)
        if match:
            evidence[key] = match.group(0)
            values[key] = exact_number(match.group(1))
    value, energy_evidence = energy_value(text)
    if energy_evidence:
        values['energy_kcal'], evidence['energy_kcal'] = value, energy_evidence
    return values, evidence


def physical_basis(text):
    if re.search(r'100\s*g\s*/\s*(?:100\s*)?ml', text, re.I):
        return None
    found = {unit.lower() for unit in re.findall(r'\b100\s*(g|ml)\b', text, re.I)}
    return {'amount': 100, 'unit': found.pop().lower()} if len(found) == 1 else None


def package(text):
    if re.search(r'\d+\s*[x×]\s*\d', text, re.I):
        return {'ambiguous_multipack': True}
    match = re.search(r'(?<!\d)(' + NUMBER + r')\s*(kg|ml|g|l)\b', text, re.I)
    if not match:
        return None
    amount, unit = float(match.group(1).replace(',', '.')), match.group(2).lower()
    return {'amount': amount * (1000 if unit in ('kg', 'l') else 1), 'unit': 'ml' if unit in ('l', 'ml') else 'g'}


def product(source, url, name, package_text, barcodes, values, basis, evidence, raw):
    return {'schema_version': 1, 'id': source + '_' + hashlib.sha256(url.encode()).hexdigest()[:20],
            'manufacturer': source, 'name': name.strip(), 'package': package(package_text),
            'barcodes': sorted(set(barcodes)), 'source_url': url, 'source_sha256': hashlib.sha256(raw).hexdigest(),
            'nutrition': values, 'basis': basis, 'nutrition_evidence': evidence,
            'preparation': 'as_sold', 'carbs_label_mode': 'unknown', 'publication_approved': False}


def parse_mlekovita(url, raw):
    tree = CatalogHtml(raw.decode('utf-8', 'replace')).root
    headings = tree.find(lambda e: e.tag == 'h1')
    sections = tree.find(lambda e: e.has_class('section__nutritional__values__box'))
    if not headings:
        return []
    # A second table can describe a serving: only an explicitly per-100 table is used.
    sections = [s for s in sections if physical_basis(s.text())]
    if len(sections) != 1:
        return [product('mlekovita', url, headings[0].text(), '', [], dict.fromkeys(KEYS), None, {}, raw)]
    text = tree.text()
    code_matches = re.findall(r'Kod kreskowy jed\.\s*:?\s*(\d{8,14})|Kod kreskowy jed\. EAN-13:\s*(\d{13})', text)
    codes = [a or b for a, b in code_matches]
    pkg = re.search(r'Opakowanie jednostkowe:\s*([^:]{1,40}?)\s*Opakowanie zbiorcze', text)
    values, evidence = nutrition(sections[0].text())
    result = product('mlekovita', url, headings[0].text(), pkg.group(1) if pkg else headings[0].text(), codes,
                     values, physical_basis(sections[0].text()), evidence, raw)
    if re.search(r'przygotowan|prepared', sections[0].text(), re.I):
        result['preparation'] = 'prepared'
    return [result]


def parse_piatnica(url, raw):
    tree = CatalogHtml(raw.decode('utf-8', 'replace')).root
    headings = tree.find(lambda e: e.tag == 'h1')
    if not headings:
        return []
    title = ' '.join(c.text() if hasattr(c, 'tag') else c for c in headings[0].children if not hasattr(c, 'tag') or c.tag != 'small').strip()
    tables = tree.find(lambda e: e.tag == 'table')
    values, evidence = dict.fromkeys(KEYS), {}
    for table in tables:
        for cell in table.find(lambda e: e.tag == 'td'):
            text = cell.text()
            spans = cell.find(lambda e: e.has_class('value'))
            if not spans:
                continue
            for key, pattern in LABELS.items():
                if re.search(r'\b' + pattern + r'\b', text, re.I):
                    # Repeated responsive cells must agree, never last-value-wins.
                    value_text = spans[0].text()
                    value = exact_number(value_text) if re.search(r'\s*g\b', value_text, re.I) else None
                    if key in evidence and values[key] != value:
                        return [product('piatnica', url, title, title, [], dict.fromkeys(KEYS), None, {}, raw)]
                    values[key], evidence[key] = value, text
            if 'energetyczna' in text.casefold():
                values['energy_kcal'], _ = energy_value(spans[0].text())
                evidence['energy_kcal'] = text
        for row in table.find(lambda e: e.tag == 'tr'):
            cells = [c for c in row.children if hasattr(c, 'tag') and c.tag in ('td', 'th')]
            if len(cells) != 2:
                continue
            for key, label in LABELS.items():
                if re.fullmatch(label, cells[0].text(), re.I):
                    value_text = cells[1].text()
                    value = exact_number(value_text) if re.search(r'\s*g\b', value_text, re.I) else None
                    if key in evidence and values[key] != value:
                        return [product('piatnica', url, title, title, [], dict.fromkeys(KEYS), None, {}, raw)]
                    values[key], evidence[key] = value, row.text()
    basis = physical_basis(' '.join(h.text() for h in tree.find(lambda e: e.tag in ('h2', 'h3', 'h4') and 'odżywcza' in e.text().lower())))
    # Weight appears twice in responsive title markup; retain the first explicit package.
    return [product('piatnica', url, title, title, [], values, basis, evidence, raw)]
