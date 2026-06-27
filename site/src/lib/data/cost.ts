/** Representative FinOps showback data. NOT real spend — illustrative figures
 *  for the cost visualisation, in USD/month. */
export interface CostItem {
  team: string;
  product: string;
  env: "prod" | "nonprod" | "demo";
  monthly: number;
}

export const costItems: CostItem[] = [
  { team: "payments", product: "checkout", env: "prod", monthly: 4200 },
  { team: "payments", product: "checkout", env: "nonprod", monthly: 900 },
  { team: "payments", product: "fraud", env: "prod", monthly: 2600 },
  { team: "payments", product: "billing", env: "prod", monthly: 1500 },
  { team: "search", product: "catalog", env: "prod", monthly: 3100 },
  { team: "search", product: "catalog", env: "nonprod", monthly: 700 },
  { team: "identity", product: "login", env: "prod", monthly: 1800 },
  { team: "identity", product: "login", env: "nonprod", monthly: 420 },
  { team: "data-platform", product: "feature-store", env: "prod", monthly: 5200 },
  { team: "data-platform", product: "feature-store", env: "nonprod", monthly: 1100 },
  { team: "web", product: "web-store", env: "prod", monthly: 2400 },
  { team: "web", product: "web-store", env: "demo", monthly: 300 },
  { team: "ml", product: "recommendations", env: "prod", monthly: 3800 },
  { team: "ml", product: "recommendations", env: "nonprod", monthly: 950 },
];

export type Dimension = "team" | "product" | "env";

export const dimensions: { id: Dimension; label: string }[] = [
  { id: "team", label: "By team" },
  { id: "product", label: "By product" },
  { id: "env", label: "By environment" },
];

export interface Bucket {
  key: string;
  total: number;
  share: number;
  topEnv: string;
}

/** Aggregate the line items by the chosen dimension, sorted high → low. */
export function aggregate(items: CostItem[], dim: Dimension): Bucket[] {
  const grand = items.reduce((s, i) => s + i.monthly, 0);
  const map = new Map<string, { total: number; env: Record<string, number> }>();
  for (const it of items) {
    const k = it[dim];
    const cur = map.get(k) ?? { total: 0, env: {} };
    cur.total += it.monthly;
    cur.env[it.env] = (cur.env[it.env] ?? 0) + it.monthly;
    map.set(k, cur);
  }
  return [...map.entries()]
    .map(([key, v]) => ({
      key,
      total: v.total,
      share: v.total / grand,
      topEnv: Object.entries(v.env).sort((a, b) => b[1] - a[1])[0][0],
    }))
    .sort((a, b) => b.total - a.total);
}

export const grandTotal = (items: CostItem[]) => items.reduce((s, i) => s + i.monthly, 0);
