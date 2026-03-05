---
name: recipe
description: Format recipe skill.
---

# Recipe Formatter Skill

## Trigger

When asked to create, format, or print a recipe from a website.

## Behaviour

### 1. Reading the Recipe

- Screenshot and scroll through the meal plan page to capture the full recipe: title, dietary tags, servings count, all ingredients with quantities, and all method steps.
- Note the meal type: **Breakfast**, **Lunch**, **Dinner**, or **Snacks**.

### 2. Serving Size Rules

| Meal type | Servings to use |
|-----------|----------------|
| Breakfast | As stated in the recipe |
| Lunch | As stated in the recipe |
| Snacks | As stated in the recipe |
| **Dinner** | **Always scale to 5 servings** |

When scaling, divide 5 by the original serving count to get the multiplier, then apply it to every ingredient quantity. Round to practical cooking units (e.g. nearest ¼ tsp, whole egg, etc.). Note approximate values with `~` where needed.

### 3. Output Format

- Navigate to the recipe's meal plan URL in a new tab, then inject the formatted recipe by calling `document.open(); document.write(html); document.close()` via JavaScript.
- The tab title should be set to the recipe name.
- The document is print-ready at **A4 size** — the user prints with Cmd+P / Ctrl+P.

### 4. HTML/CSS Template

Use the following template exactly. Do not deviate from the layout, typography, or colour scheme.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>RECIPE NAME</title>
  <style>
    @page { size: A4; margin: 16mm 18mm 16mm 18mm; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: Georgia, 'Times New Roman', serif;
      font-size: 10.5pt;
      line-height: 1.45;
      color: #1a1a1a;
      background: #fff;
      padding: 18mm;
      width: 210mm;
    }
    h1 {
      font-size: 19pt;
      font-weight: bold;
      margin-bottom: 3px;
      color: #111;
      letter-spacing: -0.01em;
    }
    .meta {
      font-size: 9pt;
      color: #666;
      font-style: italic;
      margin-bottom: 8px;
    }
    .divider {
      border: none;
      border-top: 2px solid #111;
      margin: 8px 0 12px 0;
    }
    .layout {
      display: grid;
      grid-template-columns: 38% 58%;
      gap: 20px;
    }
    .col-label {
      font-size: 7.5pt;
      font-weight: bold;
      text-transform: uppercase;
      letter-spacing: 0.14em;
      color: #888;
      border-bottom: 1px solid #ccc;
      padding-bottom: 3px;
      margin-bottom: 7px;
    }
    .sub-label {
      font-size: 7.5pt;
      font-weight: bold;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      color: #aaa;
      margin-top: 10px;
      margin-bottom: 4px;
    }
    .ing-list { list-style: none; }
    .ing-list li {
      font-size: 9.5pt;
      padding: 2.5px 0;
      border-bottom: 1px dotted #ddd;
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      gap: 6px;
    }
    .ing-list li .qty {
      color: #555;
      font-style: italic;
      font-size: 9pt;
      white-space: nowrap;
      flex-shrink: 0;
    }
    .steps-list {
      list-style: none;
      counter-reset: step-counter;
    }
    .steps-list li {
      counter-increment: step-counter;
      font-size: 9.5pt;
      margin-bottom: 7px;
      line-height: 1.4;
      padding-left: 22px;
      position: relative;
    }
    .steps-list li::before {
      content: counter(step-counter);
      position: absolute;
      left: 0;
      top: 0;
      font-weight: bold;
      font-size: 9pt;
      color: #888;
      width: 16px;
      text-align: right;
    }
    .tip {
      margin-top: 10px;
      background: #f5f5f5;
      border-left: 3px solid #aaa;
      padding: 5px 9px;
      font-size: 9pt;
      color: #555;
      font-style: italic;
    }
    .tip b { font-style: normal; color: #333; }
    .footer {
      margin-top: 12px;
      font-size: 7.5pt;
      color: #bbb;
      text-align: right;
      font-style: italic;
    }
    @media print {
      body { padding: 0; width: 100%; }
    }
  </style>
</head>
<body>
  <h1>RECIPE NAME</h1>
  <div class="meta">Makes N servings &bull; TAG1 &bull; TAG2</div>
  <hr class="divider">
  <div class="layout">
    <!-- LEFT COLUMN: Ingredients -->
    <div>
      <div class="col-label">Ingredients</div>
      <ul class="ing-list">
        <li><span>Ingredient name</span><span class="qty">amount (Xg)</span></li>
        <!-- repeat for each ingredient -->
      </ul>
      <!-- Optional sub-section (e.g. Dressing, Extra per serving) -->
      <div class="sub-label">Sub-section title</div>
      <ul class="ing-list">
        <li><span>Ingredient</span><span class="qty">amount</span></li>
      </ul>
    </div>
    <!-- RIGHT COLUMN: Method -->
    <div>
      <div class="col-label">Method</div>
      <ol class="steps-list">
        <li>Step one text. <b>Bold key details</b> like temperatures and times.</li>
        <!-- repeat for each step -->
      </ol>
      <div class="tip"><b>Tip:</b> Tip text here.</div>
    </div>
  </div>
  <div class="footer">MEAL TYPE</div>
</body>
</html>
```

### 5. Content Rules

**Title (`h1`):** Title-case recipe name.
**Meta line:** `Makes N servings • Tag1 • Tag2` — dietary tags drawn from the recipe badges (e.g. Vegetarian, Gluten-Free, Low Fat).
**Ingredients (left column, 38% width):**
- Each `<li>` has the ingredient name on the left and quantity (italicised) on the right.
- Use proper HTML fractions: `&frac12;` `&frac14;` `&frac34;` `&frac13;` `&frac23;` — not typed fractions.
- Include the gram weight in parentheses where provided.
- If the recipe has a distinct sub-group (e.g. Dressing, Extra per serving), use `.sub-label` to separate it.
**Method (right column, 58% width):**
- Consolidate method steps to be concise — remove meal-plan-specific preamble ("prepare according to instructions below", "enjoy half for dinner", etc.).
- **Bold** key values: temperatures, cook times, critical quantities (e.g. `<b>180°C fan-forced</b>`, `<b>35–40 minutes</b>`, `<b>15 minutes before</b>`).
- If a TIP is present in the original recipe, include it in the `.tip` box.
**Footer:** If ingredients were scaled, append `| Scaled to N servings`.
**Scaling note:** If dinner was scaled, add a practical note in the relevant step (e.g. "You may need a second pan for the larger batch").
