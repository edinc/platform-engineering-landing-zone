export type AzureCostInsightRecord = {
  team: string;
  product: string;
  costCenter: string;
  environment: string;
  pretaxCost: number;
  currency: string;
  periodStart: string;
  periodEnd: string;
};

export type CostInsightsGroup = {
  id: string;
  name: string;
  aggregation: 'team' | 'product' | 'costCenter';
};

export function groupAzureCostRecords(records: AzureCostInsightRecord[], aggregation: CostInsightsGroup['aggregation']) {
  return records.reduce<Record<string, number>>((totals, record) => {
    const key = record[aggregation];
    totals[key] = (totals[key] ?? 0) + record.pretaxCost;
    return totals;
  }, {});
}
