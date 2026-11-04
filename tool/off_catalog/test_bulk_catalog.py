import copy
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
import tempfile
import unittest

from bulk_catalog import discover, download, SOURCES
from common.catalog_http import CatalogHttp
from common.catalog_matching import match_product, name_identity
from common.catalog_parsers import parse_mlekovita, parse_piatnica, physical_basis
from match_bulk_catalogs import match


def mlekovita_html(fat='12', second=''):
    return ('''<h1>Śmietana Polska 12%</h1><div class="section__nutritional__values__box">
        <span>w 100 g</span><ul><li>Wart. energetyczna: 560 kJ / 135 kcal</li>
        <li>Tłuszcz: ''' + fat + ''' g</li><li>Węglowodany: 4,0 g</li><li>Białko: 2,8 g</li></ul></div>'''
        + second + '<p>Opakowanie jednostkowe: 200 g Opakowanie zbiorcze: 12 szt. Kod kreskowy jed.: 5900512350011</p>').encode()


def original(name='Śmietana Polska 12%', brand='Mlekovita', code='local-source-id', quantity='200 g'):
    return {'id': 'off_' + code, 'source_id': code, 'name': name, 'brand': brand, 'quantity': quantity,
            'nutrition_as_exported': dict.fromkeys(('carbs', 'fiber', 'fat', 'protein', 'energy_kcal'))}


def source():
    return parse_mlekovita('https://mlekovita.com.pl/produkt/smietana', mlekovita_html())[0]


class BulkParserTest(unittest.TestCase):
    def test_real_manufacturer_contract_preserves_missing_fiber_and_per_100_values(self):
        product = source()
        self.assertEqual(product['barcodes'], ['5900512350011'])
        self.assertEqual(product['nutrition'], {'carbs': 4, 'fiber': None, 'fat': 12, 'protein': 2.8, 'energy_kcal': 135})
        self.assertEqual(product['package'], {'amount': 200, 'unit': 'g'})
        self.assertEqual(product['basis'], {'amount': 100, 'unit': 'g'})

    def test_portion_table_cannot_override_100g(self):
        extra = '<div class="section__nutritional__values__box">w porcji 50 g Tłuszcz: 6 g Białko: 1,4 g Węglowodany: 2 g</div>'
        product = parse_mlekovita('https://mlekovita.com.pl/produkt/test', mlekovita_html(second=extra))[0]
        self.assertEqual(product['nutrition']['fat'], 12)

    def test_qualified_values_remain_unknown_with_evidence(self):
        product = parse_mlekovita('https://mlekovita.com.pl/produkt/test', mlekovita_html(fat='&lt;0,5'))[0]
        self.assertIsNone(product['nutrition']['fat'])
        self.assertIn('<0,5', product['nutrition_evidence']['fat'])

    def test_ambiguous_100g_ml_basis_is_not_guessed(self):
        self.assertIsNone(physical_basis('Wartości w 100g/ml'))
        self.assertIsNone(physical_basis('100 g oraz 100 ml'))
        self.assertEqual(physical_basis('w 100 ml'), {'amount': 100, 'unit': 'ml'})

    def test_energy_bounds_are_not_converted_to_exact_calories(self):
        raw = mlekovita_html().replace(b'135 kcal', b'&lt; 5 kcal')
        p = parse_mlekovita('https://mlekovita.com.pl/produkt/test', raw)[0]
        self.assertIsNone(p['nutrition']['energy_kcal'])
        self.assertIn('< 5', p['nutrition_evidence']['energy_kcal'])
        raw = '<h1>Skyr</h1><h3>Wartość odżywcza w 100 g:</h3><table><tr><td><span class="value">&lt; 5 kcal</span>Wartość energetyczna</td></tr></table>'.encode()
        self.assertIsNone(parse_piatnica('https://piatnica.com.pl/produkt/skyr', raw)[0]['nutrition']['energy_kcal'])

    def test_prepared_nutrition_is_not_used_for_as_sold_product(self):
        raw = mlekovita_html().replace(b'w 100 g', 'w 100 g produktu po przygotowaniu'.encode())
        p = parse_mlekovita('https://mlekovita.com.pl/produkt/test', raw)[0]
        self.assertEqual(p['preparation'], 'prepared')
        result = match_product(original(), [p])
        self.assertEqual(result['status'], 'exception')
        self.assertIn('preparation_basis_requires_review', result['reason'])

    def test_energy_ranges_remain_unknown_in_both_adapters(self):
        for value in ['10–20 kcal', '10 - 20 kcal', '10 — 20 kcal']:
            raw = mlekovita_html().replace(b'135 kcal', value.encode())
            self.assertIsNone(parse_mlekovita('https://mlekovita.com.pl/produkt/test', raw)[0]['nutrition']['energy_kcal'])
            raw = ('<h1>Skyr</h1><h3>Wartość odżywcza w 100 g:</h3><table><tr><td><span class="value">' + value + '</span>Wartość energetyczna</td></tr></table>').encode()
            self.assertIsNone(parse_piatnica('https://piatnica.com.pl/produkt/skyr', raw)[0]['nutrition']['energy_kcal'])

    def test_negative_source_values_are_not_made_positive(self):
        raw = mlekovita_html(fat='-2').replace(b'135 kcal', b'-5 kcal')
        result = parse_mlekovita('https://mlekovita.com.pl/produkt/test', raw)[0]
        self.assertIsNone(result['nutrition']['fat'])
        self.assertIsNone(result['nutrition']['energy_kcal'])

    def test_two_different_100g_tables_are_held(self):
        html = mlekovita_html(second='<div class="section__nutritional__values__box">w 100 g Tłuszcz: 20 g</div>')
        product = parse_mlekovita('https://mlekovita.com.pl/produkt/test', html)[0]
        self.assertIsNone(product['basis'])

    def test_piatnica_without_barcode_has_stable_identity_and_complete_nutrition(self):
        html = b'''<h1>Skyr Naturalny 450 g <small>450 g</small></h1><h3>Warto\xc5\x9b\xc4\x87 od\xc5\xbcywcza w 100 g:</h3>
          <table><tr><td><span class="value">64 kcal</span><p>Warto\xc5\x9b\xc4\x87 energetyczna</p></td>
          <td><span class="value">12 g</span><p>Bia\xc5\x82ko</p></td><td><span class="value">0 g</span><p>T\xc5\x82uszcz</p></td></tr>
          <tr><td>W\xc4\x99glowodany</td><td>4,1 g</td></tr></table>'''
        p = parse_piatnica('https://piatnica.com.pl/produkt/skyr', html)[0]
        self.assertEqual(p['name'], 'Skyr Naturalny 450 g')
        self.assertEqual(p['barcodes'], [])
        self.assertEqual(p['nutrition']['carbs'], 4.1)
        self.assertEqual(p['nutrition']['fat'], 0)
        self.assertEqual(p['id'], parse_piatnica(p['source_url'], html)[0]['id'])


class CatalogMatchTest(unittest.TestCase):
    def test_name_manufacturer_variant_match_needs_no_barcode(self):
        p = source(); p['barcodes'] = []
        before = original()
        result = match_product(before, [p])
        self.assertEqual(result['status'], 'source_backed_proposal')
        self.assertEqual(result['match_method'], 'exact_manufacturer_name_variant')
        self.assertEqual(result['nutrition_proposal']['carbs'], 4)
        self.assertIsNone(before['nutrition_as_exported']['carbs'])
        self.assertIsNone(result['nutrition_proposal']['fiber'])
        self.assertFalse(result['retains_original_nutrient_values'])
        self.assertEqual(result['apply_strategy'], 'replace_complete_nutrition_after_review')
        self.assertFalse(result['barcode_required'])

    def test_other_manufacturer_or_flavor_cannot_match_by_similarity(self):
        self.assertEqual(match_product(original(brand='Bakoma'), [source()])['status'], 'exception')
        p = source(); p['name'] = 'Jogurt truskawkowy'; p['barcodes'] = []
        self.assertEqual(match_product(original(name='Jogurt brzoskwiniowy'), [p])['status'], 'exception')

    def test_code_does_not_override_fat_percentage_conflict(self):
        result = match_product(original(name='Śmietana Polska 18%', code='5900512350011'), [source()])
        self.assertEqual(result['reason'], 'barcode_name_conflict')

    def test_name_match_rejects_different_packages_or_ambiguous_sources(self):
        self.assertEqual(match_product(original(quantity='200 ml'), [source()])['status'], 'exception')
        p = source(); other = copy.deepcopy(p); other['id'] = 'other'
        self.assertEqual(match_product(original(), [p, other])['reason'], 'ambiguous_identity')

    def test_multipack_is_not_mistaken_for_single_package(self):
        self.assertEqual(match_product(original(quantity='4 x 200 g'), [source()])['status'], 'exception')

    def test_multipack_name_cannot_be_hidden_by_single_quantity(self):
        p = source(); p['name'] = 'Jogurt naturalny 4 x 200 g'
        target = original(name=p['name'], quantity='200 g', code='5900512350011')
        self.assertEqual(match_product(target, [p])['status'], 'exception')

    def test_matching_code_cannot_hide_additional_lactose_variant(self):
        p = source(); p['name'] = 'Jogurt naturalny bez laktozy'
        result = match_product(original(name='Jogurt naturalny', code='5900512350011'), [p])
        self.assertEqual(result['reason'], 'barcode_name_conflict')

    def test_profile_is_atomic_even_when_old_basis_is_unknown(self):
        target = original(); target['nutrition_basis'] = 'unknown_100g_or_100ml'
        target['nutrition_as_exported']['fiber'] = 10
        result = match_product(target, [source()])
        self.assertIsNone(result['nutrition_proposal']['fiber'])
        self.assertFalse(result['retains_original_nutrient_values'])

    def test_optional_barcode_does_not_mean_known_conflicting_codes_are_ignored(self):
        result = match_product(original(code='5900512350012'), [source()])
        self.assertEqual(result['reason'], 'barcode_disagreement')

    def test_existing_facts_are_not_overwritten(self):
        target = original(); target['nutrition_as_exported']['fat'] = 18
        result = match_product(target, [source()])
        self.assertEqual(result['status'], 'exception')
        self.assertIsNone(result['nutrition_proposal'])
        self.assertIn('existing_nutrition_conflict_fat', result['reason'])

    def test_brand_matching_uses_word_boundaries(self):
        p = source(); p['manufacturer'] = 'osm'; p['name'] = 'Test'
        self.assertEqual(match_product(original(name='Test', brand='cosmetics'), [p])['status'], 'exception')


class SitemapTest(unittest.TestCase):
    def test_product_map_is_followed_but_recipes_and_foreign_links_are_not(self):
        class Client:
            def allowed(self, url): return url.startswith('https://maker.example/')
            def read(self, url):
                if url.endswith('index.xml'):
                    return b'<sitemapindex><sitemap><loc>https://maker.example/product.xml</loc></sitemap><sitemap><loc>https://maker.example/recipes.xml</loc></sitemap></sitemapindex>'
                return b'<urlset><url><loc>https://maker.example/produkt/a</loc></url><url><loc>https://foreign.example/produkt/b</loc></url></urlset>'
        self.assertEqual(discover(Client(), 'https://maker.example/index.xml', '/produkt/'), ['https://maker.example/produkt/a'])

    def test_html_is_not_treated_as_an_empty_successful_catalog(self):
        class Client:
            def read(self, url): return b'<html><body>SPA shell</body></html>'
            def allowed(self, url): return True
        with self.assertRaises(ValueError):
            discover(Client(), 'https://maker.example/sitemap.xml', '/produkt/')


class PipelineBoundaryTest(unittest.TestCase):
    def test_complete_download_uses_injected_http_boundary(self):
        class Client:
            def __init__(self, *args, **kwargs): self.requests, self.cache_hits = 2, 0
            def allowed(self, url): return url.startswith('https://mlekovita.com.pl/')
            def read(self, url):
                if url.endswith('.xml'):
                    return b'<urlset><url><loc>https://mlekovita.com.pl/produkt/test</loc></url></urlset>'
                return mlekovita_html()
        with tempfile.TemporaryDirectory() as directory, patch('bulk_catalog.CatalogHttp', Client):
            manifest = download('mlekovita', Path(directory))
            self.assertTrue(manifest['complete'])
            self.assertEqual(manifest['products_with_core_macros'], 1)
            self.assertEqual(manifest['parsed_products'], 1)

    def test_empty_discovery_never_publishes_complete_catalog(self):
        class Client:
            def __init__(self, *args, **kwargs): pass
            def read(self, url): return b'<urlset/>'
            def allowed(self, url): return True
        with tempfile.TemporaryDirectory() as directory, patch('bulk_catalog.CatalogHttp', Client):
            with self.assertRaisesRegex(ValueError, 'No product URLs'):
                download('mlekovita', Path(directory))
            self.assertFalse((Path(directory) / 'mlekovita/manifest.json').exists())

    def test_partial_or_mismatched_snapshot_cannot_produce_matches(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); catalog = root / 'source'; catalog.mkdir()
            raw = (json.dumps(source()) + '\n').encode()
            (catalog / 'catalog.jsonl').write_bytes(raw)
            manifest = {'complete': False, 'catalog_sha256': hashlib.sha256(raw).hexdigest()}
            (catalog / 'manifest.json').write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'Incomplete'):
                match(root / 'unused.sqlite', [catalog], root / 'output')
            manifest.update(complete=True, catalog_sha256='incorrect')
            (catalog / 'manifest.json').write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'snapshot mismatch'):
                match(root / 'unused.sqlite', [catalog], root / 'output')


if __name__ == '__main__':
    unittest.main()
