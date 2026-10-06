import re, sys
root = sys.argv[1]
src = open(root + '/src/sim/templates.ts', encoding='utf8').read()
body = src[src.index('export const TEMPLATES'):src.index('export const TEMPLATE_CATEGORIES')]
blocks = re.split(r'\n  \{\n', body)[1:]

def conv_params(p):
    items = re.findall(r'(\w+):\s*([\d.]+)', p or '')
    if not items:
        return ''
    return ', {' + ', '.join(f'ParamKey.{k}: {v}' for k, v in items) + '}'

def g(b, k):
    m = re.search(k + r':\s*\n?\s*"(.*?)",?\n', b, re.S)
    return m.group(1)

esc = lambda s: s.replace("'", "\\'")
res = []
for b in blocks:
    gid, name, cat, summ, tryt = (g(b, k) for k in ['id', 'name', 'category', 'summary', 'tryThis'])
    summ = re.sub(r'"\s*$', '', summ)
    traffic = re.search(r'traffic:\s*(\d+)', b).group(1)
    nodes = re.findall(r'n\("(\w+)", "(\w+)", "([^"]+)", ([\d.]+), ([\d.]+)(?:, \{([^}]*)\})?\)', b)
    edges = re.findall(r'\["(\w+)", "(\w+)"(?:, \{ latencyMs: (\d+) \})?\]', b)
    catd = 'TemplateCategory.patrones' if cat == 'Patrones' else 'TemplateCategory.reales'
    lines = [f"  Template(\n    id: '{gid}',\n    name: '{esc(name)}',\n    category: {catd},\n    summary: '{esc(summ)}',\n    tryThis: '{esc(tryt)}',\n    traffic: {traffic},\n    nodes: ["]
    for k, kind, label, c, r, p in nodes:
        lines.append(f"      _n('{k}', ComponentKind.{kind}, '{esc(label)}', {c}, {r}{conv_params(p)}),")
    lines.append("    ],\n    edges: [")
    for a, bb, lat in edges:
        lines.append(f"      TemplateEdge('{a}', '{bb}'{', latencyMs: ' + lat if lat else ''}),")
    lines.append("    ],\n  ),")
    res.append('\n'.join(lines))
    print(gid, len(nodes), len(edges), '|', summ[:50])

head = open(root + '/app/tool/templates_head.dart.txt', encoding='utf8').read()
tail = '''];

const List<TemplateCategory> templateCategories = TemplateCategory.values;

Template? templateById(String id) {
  for (final t in templates) {
    if (t.id == id) return t;
  }
  return null;
}
'''
open(root + '/app/lib/sim/templates.dart', 'w', encoding='utf8').write(head + '\n'.join(res) + '\n' + tail)
