---
name: make-pancakes
description: >-
  Generates a pancake recipe card scaled to the requested serving count.
  Use when the user asks for pancake recipes or batch scaling. Do not use
  for other baked goods.
---

# Pancake recipe cards

1. Scale the base recipe to the serving count.
2. Render the recipe card as Markdown.

Do not exceed 4x scaling without warning about pan size.

```text
Servings: 8 -> flour 500g, milk 600ml, eggs 4
```

Validate the card by re-reading the ratios; if a ratio drifts, fix the
scaling and repeat.
