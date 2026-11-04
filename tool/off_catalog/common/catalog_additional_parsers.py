"""Adapters for public, explicitly per-100 nutrition tables."""

import re
from .catalog_html import CatalogHtml
from .catalog_parsers import KEYS, nutrition, physical_basis, product


def parse_declared_table(manufacturer, url, raw, selector):
    tree=CatalogHtml(raw.decode('utf-8','replace')).root
    headings=tree.find(lambda e:e.tag=='h1')
    if not headings and manufacturer=='lowicz':
        headings=tree.find(lambda e:e.tag=='h2' and e.has_class('heading'))
    if not headings:
        return []
    name=headings[0].text()
    tables=tree.find(selector)
    tables=[t for t in tables if physical_basis(t.text())]
    candidates=[]
    for table in tables:
        text=table.text()
        # Multi-column serving tables need a dedicated adapter, not a guess.
        if re.search(r'porcj|serving',text,re.I):
            continue
        values,evidence=nutrition(text)
        if all(values.get(k) is not None for k in ('carbs','fat','protein')):
            candidates.append((values,physical_basis(text),evidence,text))
    if not candidates:
        return [product(manufacturer,url,name,name,[],dict.fromkeys(KEYS),None,{},raw)]
    first=candidates[0]
    if any((v,b)!=(first[0],first[1]) for v,b,_,_ in candidates[1:]):
        return [product(manufacturer,url,name,name,[],dict.fromkeys(KEYS),None,{},raw)]
    result=product(manufacturer,url,name,name,[],first[0],first[1],first[2],raw)
    if re.search(r'przygotowan|prepared',first[3],re.I):result['preparation']='prepared'
    return [result]


def parse_sante(url,raw):
    return parse_declared_table('sante',url,raw,lambda e:e.tag=='table' and e.has_class('nutri-table'))


def parse_lowicz(url,raw):
    return parse_declared_table('lowicz',url,raw,lambda e:e.tag=='div' and e.has_class('table') and 'Wartość odżywcza' in e.text())
