import json

with open('tests/golden/solid_shapes.forensics.json') as f:
    s = json.load(f)

print('=== SOLID SHAPES FORENSICS REPORT ===')
print('page_count:', s['page_count'])
print('sha256:', s['sha256'][:16], '...')
print('dominant_class:', s['dominant_class'])
for p in s['pages']:
    print(f"  p{p['page_no']:02d}: class={p['page_class']:<18} imgs={p['n_embedded_images']:<3} drawings={p['n_drawings']:<3} chars={p['n_chars']:<4} dpi_med={p['image_dpi_median']} trust={p['text_trust']}")

with open('tests/golden/trail_august.forensics.json') as f:
    t = json.load(f)

print()
print('=== TRAIL AUGUST FORENSICS REPORT ===')
print('page_count:', t['page_count'])
print('dominant_class:', t['dominant_class'])
for p in t['pages']:
    print(f"  p{p['page_no']:02d}: class={p['page_class']:<18} imgs={p['n_embedded_images']:<3} drawings={p['n_drawings']:<3} chars={p['n_chars']:<4} rot_spans={p['rotated_text_span_count']}")
