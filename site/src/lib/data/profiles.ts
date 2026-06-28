/** Environment profiles and how posture changes across them. Sourced from
 *  docs/architecture/README.md (environment profiles + trust posture). */
export type ProfileId = "demo" | "nonprod" | "prod";

export const profiles: { id: ProfileId; label: string; intent: string }[] = [
  { id: "demo", label: "demo", intent: "Low-cost evaluation" },
  { id: "nonprod", label: "nonprod", intent: "Pre-production validation" },
  { id: "prod", label: "prod", intent: "Production" },
];

export type Category = "cost" | "availability" | "security";

export interface PostureRow {
  id: string;
  label: string;
  icon: string;
  category: Category;
  values: Record<ProfileId, string>;
}

export const posture: PostureRow[] = [
  {
    id: "egress",
    label: "Egress & network",
    icon: "shield",
    category: "security",
    values: {
      demo: "NAT Gateway egress",
      nonprod: "Firewall, reduced rules",
      prod: "Azure Firewall Premium · default-deny",
    },
  },
  {
    id: "availability",
    label: "Availability",
    icon: "layers",
    category: "availability",
    values: {
      demo: "Single zone",
      nonprod: "Reduced redundancy",
      prod: "Zone-redundant + DR region",
    },
  },
  {
    id: "database",
    label: "Postgres",
    icon: "boxes",
    category: "availability",
    values: {
      demo: "Single-AZ",
      nonprod: "HA, no PITR",
      prod: "HA + PITR + customer-managed keys",
    },
  },
  {
    id: "registry",
    label: "Container registry",
    icon: "boxes",
    category: "availability",
    values: {
      demo: "ACR Standard",
      nonprod: "ACR Standard",
      prod: "ACR Premium · geo-replicated",
    },
  },
  {
    id: "defender",
    label: "Defender for Cloud",
    icon: "shield-check",
    category: "security",
    values: {
      demo: "Free tier",
      nonprod: "Standard (subset)",
      prod: "Defender standard",
    },
  },
  {
    id: "ingress",
    label: "Backstage ingress",
    icon: "lock",
    category: "security",
    values: {
      demo: "Public (for easy access)",
      nonprod: "Private, restricted",
      prod: "Private · Front Door",
    },
  },
  {
    id: "cost",
    label: "Relative cost",
    icon: "coins",
    category: "cost",
    values: {
      demo: "Lowest",
      nonprod: "Moderate",
      prod: "Highest",
    },
  },
];

export const categoryMeta: Record<Category, { label: string; fill: string; ink: string }> = {
  cost: { label: "Cost", fill: "var(--cat-5)", ink: "var(--cat-5-ink)" },
  availability: { label: "Availability", fill: "var(--cat-3)", ink: "var(--cat-3-ink)" },
  security: { label: "Security", fill: "var(--cat-1)", ink: "var(--cat-1-ink)" },
};

/** The posture summarised as three meters (max level = 3). The story the section
 *  tells: cost and resilience scale up demo -> prod, while the security baseline
 *  stays maxed on every profile. */
export interface Meter {
  id: string;
  label: string;
  icon: string;
  category: Category;
  note?: string;
  levels: Record<ProfileId, { n: number; word: string }>;
}

export const meters: Meter[] = [
  {
    id: "cost",
    label: "Monthly cost",
    icon: "coins",
    category: "cost",
    levels: {
      demo: { n: 1, word: "Lowest" },
      nonprod: { n: 2, word: "Moderate" },
      prod: { n: 3, word: "Highest" },
    },
  },
  {
    id: "resilience",
    label: "Resilience",
    icon: "layers",
    category: "availability",
    levels: {
      demo: { n: 1, word: "Single zone" },
      nonprod: { n: 2, word: "Reduced redundancy" },
      prod: { n: 3, word: "Zone-redundant + DR" },
    },
  },
  {
    id: "security",
    label: "Security baseline",
    icon: "shield",
    category: "security",
    note: "constant",
    levels: {
      demo: { n: 3, word: "Full" },
      nonprod: { n: 3, word: "Full" },
      prod: { n: 3, word: "Full" },
    },
  },
];
