import unittest
from common.catalog_additional_parsers import parse_sante, parse_lowicz


class AdditionalCatalogTest(unittest.TestCase):
    def test_sante_unclosed_table_rows_preserve_values(self):
        html='<h1>Otręby owsiane 200 g</h1><table class="nutri-table"><tr><td>Wartość odżywcza w 100 g produktu</td><tr><td>Wartość energetyczna</td><td>1528 kJ / 364 kcal</td><tr><td>Tłuszcz</td><td>8,7 g</td><tr><td>Węglowodany</td><td>44 g</td><tr><td>Białko</td><td>18 g</td></table>'
        p=parse_sante('https://sante.pl/produkty/otreby',html.encode())[0]
        self.assertEqual(p['nutrition']['carbs'],44)
        self.assertEqual(p['nutrition']['protein'],18)
        self.assertIsNone(p['nutrition']['fiber'])
        self.assertEqual(p['basis'],{'amount':100,'unit':'g'})
        self.assertEqual(p['barcodes'],[])

    def test_lowicz_h2_title_and_explicit_nutrition_block(self):
        html='<h2 class="heading">Serek wiejski 200 g</h2><div class="table"><div>Wartość odżywcza w 100 g</div><ul><li>Tłuszcz 5 g</li><li>Węglowodany 3 g</li><li>Białko 11 g</li></ul></div>'
        p=parse_lowicz('https://mleczarnia.lowicz.pl/produkt/serek',html.encode())[0]
        self.assertEqual(p['name'],'Serek wiejski 200 g')
        self.assertEqual(p['nutrition']['fat'],5)
        self.assertEqual(p['nutrition']['protein'],11)

    def test_incomplete_or_serving_table_is_not_invented(self):
        html='<h1>Deser</h1><table class="nutri-table">Wartość odżywcza w 100 g i w porcji Tłuszcz 5 g Węglowodany 3 g Białko 11 g</table>'
        p=parse_sante('https://sante.pl/produkty/deser',html.encode())[0]
        self.assertIsNone(p['basis'])
        self.assertIsNone(p['nutrition']['carbs'])


if __name__=='__main__':unittest.main()
