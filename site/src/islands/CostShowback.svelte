<script lang="ts">
  import { costItems, dimensions, aggregate, grandTotal, type Dimension } from "../lib/data/cost";
  import { repoPath } from "../lib/base";

  let dim = $state<Dimension>("team");
  const buckets = $derived(aggregate(costItems, dim));
  const max = $derived(buckets[0]?.total ?? 1);
  const total = grandTotal(costItems);

  const fmt = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  });
  const pct = (n: number) => `${Math.round(n * 100)}%`;

  function onKeydown(e: KeyboardEvent) {
    const idx = dimensions.findIndex((d) => d.id === dim);
    let next = -1;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (idx + 1) % dimensions.length;
    else if (e.key === "ArrowLeft" || e.key === "ArrowUp")
      next = (idx - 1 + dimensions.length) % dimensions.length;
    if (next >= 0) {
      e.preventDefault();
      dim = dimensions[next].id;
      requestAnimationFrame(() => document.getElementById(`cost-${dim}`)?.focus());
    }
  }
</script>

<div class="cost">
  <div class="cost__head">
    <div class="cost__toggle" role="radiogroup" aria-label="Group cost by" onkeydown={onKeydown}>
      {#each dimensions as d (d.id)}
        <button
          type="button"
          role="radio"
          id={`cost-${d.id}`}
          class="cost__opt"
          class:is-active={dim === d.id}
          aria-checked={dim === d.id}
          tabindex={dim === d.id ? 0 : -1}
          onclick={() => (dim = d.id)}
        >
          {d.label}
        </button>
      {/each}
    </div>
    <div class="cost__total">
      <span class="cost__total-label">Monthly showback</span>
      <span class="cost__total-value tnum">{fmt.format(total)}</span>
      <span class="cost__rep">representative</span>
    </div>
  </div>

  <ul class="cost__chart" role="list" aria-label={`Cost ${dimensions.find((d) => d.id === dim)?.label.toLowerCase()}`}>
    {#each buckets as b (b.key)}
      <li class="cost__row">
        <span class="cost__key">{b.key}</span>
        <span class="cost__bar" aria-hidden="true">
          <span class="cost__fill" style={`transform: scaleX(${b.total / max})`}></span>
        </span>
        <span class="cost__val">
          <span class="cost__amount tnum">{fmt.format(b.total)}</span>
          <span class="cost__share tnum">{pct(b.share)}</span>
        </span>
      </li>
    {/each}
  </ul>

  <p class="cost__note">
    Figures are clearly-labelled representative data, in USD per month. In the
    platform, mandatory <code>owner</code>, <code>product</code> and
    <code>costCenter</code> tags drive real
    <a href={repoPath("docs/how-it-works/observability-sre-finops.md")} target="_blank" rel="noopener"
      >showback in Backstage Cost Insights</a
    >.
  </p>
</div>

<style>
  .cost {
    margin-top: var(--s-xl);
    border: var(--hair) solid var(--hairline);
    border-radius: var(--radius-lg);
    background: var(--bg);
    padding: clamp(1.25rem, 1rem + 1.5vw, 2rem);
    box-shadow: var(--shadow-sm);
  }
  .cost__head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: var(--s-md);
    margin-bottom: var(--s-lg);
  }
  .cost__toggle {
    display: inline-flex;
    padding: 4px;
    gap: 2px;
    background: var(--surface-sunken);
    border-radius: var(--radius-pill);
    border: var(--hair) solid var(--hairline);
  }
  .cost__opt {
    padding: 0.45rem 0.95rem;
    border-radius: var(--radius-pill);
    font-size: 0.86rem;
    font-weight: var(--w-medium);
    color: var(--muted);
    transition:
      color var(--dur-1) var(--ease-out-quart),
      background var(--dur-1) var(--ease-out-quart);
  }
  .cost__opt:hover {
    color: var(--ink);
  }
  .cost__opt.is-active {
    color: var(--accent-ink);
    background: var(--accent);
    box-shadow: var(--shadow-sm);
  }
  .cost__total {
    display: flex;
    align-items: baseline;
    gap: 0.5rem;
  }
  .cost__total-label {
    font-size: 0.8rem;
    color: var(--faint);
  }
  .cost__total-value {
    font-size: 1.5rem;
    font-weight: var(--w-bold);
    letter-spacing: -0.01em;
  }
  .cost__rep {
    font-family: var(--font-mono);
    font-size: 0.66rem;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--faint);
    border: var(--hair) solid var(--hairline-strong);
    padding: 0.1rem 0.4rem;
    border-radius: var(--radius-sm);
  }

  .cost__chart {
    display: flex;
    flex-direction: column;
    gap: 0.55rem;
  }
  .cost__row {
    display: grid;
    grid-template-columns: minmax(7rem, 10rem) 1fr auto;
    align-items: center;
    gap: var(--s-md);
  }
  .cost__key {
    font-weight: var(--w-medium);
    font-size: 0.92rem;
    color: var(--ink);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .cost__bar {
    height: 1.5rem;
    background: var(--surface-sunken);
    border-radius: var(--radius-sm);
    overflow: hidden;
    position: relative;
  }
  .cost__fill {
    display: block;
    height: 100%;
    border-radius: var(--radius-sm);
    transform-origin: left;
    background: linear-gradient(90deg, var(--accent-deep), var(--accent));
    transition: transform var(--dur-3) var(--ease-out-expo);
  }
  .cost__val {
    display: inline-flex;
    align-items: baseline;
    gap: 0.55rem;
    min-width: 6.5rem;
    justify-content: flex-end;
  }
  .cost__amount {
    font-weight: var(--w-semibold);
    font-size: 0.95rem;
  }
  .cost__share {
    font-size: 0.78rem;
    color: var(--faint);
    width: 2.5rem;
    text-align: right;
  }
  .cost__note {
    margin-top: var(--s-lg);
    padding-top: var(--s-md);
    border-top: var(--hair) solid var(--hairline);
    font-size: 0.85rem;
    color: var(--muted);
    max-width: 64ch;
  }
  .cost__note code {
    background: var(--surface-sunken);
    padding: 0.05em 0.35em;
    border-radius: var(--radius-sm);
    font-size: 0.82em;
    color: var(--ink);
  }

  @media (max-width: 560px) {
    .cost__row {
      grid-template-columns: minmax(5.5rem, 8rem) 1fr;
    }
    .cost__val {
      grid-column: 2;
      justify-content: flex-start;
      min-width: 0;
    }
    .cost__bar {
      grid-column: 1 / -1;
      order: 3;
    }
  }
</style>
