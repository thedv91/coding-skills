# Worked example — one card, start to finish

Loaded on demand from `SKILL.md`. Read it when the naming rules need to be seen applied
rather than stated; the framework changes the syntax, not the reasoning.

Before — nothing here is reachable
except by CSS class, and nothing in the DOM says `PaymentSummary`:

```jsx
export function PaymentSummary({ order }) {
  return (
    <section className="card">
      <span className="total">{formatMoney(order.total)}</span>
      {order.lines.map((line) => <OrderLine key={line.id} line={line} />)}
      <IconButton icon="check" onClick={submit} />
    </section>
  );
}
```

After:

```jsx
export function PaymentSummary({ order }) {
  return (
    <section className="card" data-testid="payment-summary">
      <span className="total" data-testid="payment-summary-total">{formatMoney(order.total)}</span>
      {order.lines.map((line) => (
        <OrderLine key={line.id} line={line} data-testid={`payment-summary-line-${line.id}`} />
      ))}
      <IconButton icon="check" onClick={submit} data-testid="payment-summary-submit" />
    </section>
  );
}
```

Four decisions worth reading back:

- `payment-summary` is the **root anchor** — it exists so an inspected node inside this card
  leads to this file, not because a test asked for it.
- The total gets one because the rendered text is formatted and localized; asserting on
  `"$1,240.00"` is asserting on the formatter.
- The line id keeps a **static prefix** (`payment-summary-line-`) so the grep round-trip
  works even though the tail is interpolated — and uses `line.id`, not the map index.
- The icon button has no accessible name to select by, which is exactly the case test ids
  exist for. But `IconButton` and `OrderLine` are **other components**: the attribute is a
  prop until they forward it to a DOM node. Check that before calling this done — see
  [`frameworks.md`](frameworks.md) — or the DOM ends up with no id and
  the diff still looks right.

Nothing else in the card was touched: the `className="card"` wrapper, the layout divs, and
every leaf inside `OrderLine` stay bare.

