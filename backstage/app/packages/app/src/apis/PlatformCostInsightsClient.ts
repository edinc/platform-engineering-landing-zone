import {
  Cost,
  CostInsightsApi,
  Entity,
  Group,
  MetricData,
  ProductInsightsOptions,
  Project,
  Alert,
} from '@backstage-community/plugin-cost-insights';
import { DiscoveryApi, FetchApi } from '@backstage/core-plugin-api';

type ShowbackRecord = {
  team: string;
  product: string;
  costCenter: string;
  environment: string;
  pretaxCost: number;
  currency: string;
  periodStart: string;
  periodEnd: string;
};

export class PlatformCostInsightsClient implements CostInsightsApi {
  constructor(
    private readonly discoveryApi: DiscoveryApi,
    private readonly fetchApi: FetchApi,
  ) {}

  private async records(): Promise<ShowbackRecord[]> {
    const baseUrl = await this.discoveryApi.getBaseUrl(
      'platform-cost-showback',
    );
    const response = await this.fetchApi.fetch(`${baseUrl}/records`);
    if (!response.ok) {
      throw new Error(
        `Failed to load platform cost showback: ${response.status}`,
      );
    }
    return response.json() as Promise<ShowbackRecord[]>;
  }

  async getLastCompleteBillingDate(): Promise<string> {
    const records = await this.records();
    return (
      records
        .map(record => record.periodEnd)
        .sort()
        .at(-1) ?? new Date().toISOString().slice(0, 10)
    );
  }

  async getUserGroups(_userId: string): Promise<Group[]> {
    const records = await this.records();
    return [...new Set(records.map(record => record.team))].map(team => ({
      id: team,
      name: team,
    }));
  }

  async getGroupProjects(group: string): Promise<Project[]> {
    const records = await this.records();
    return [
      ...new Set(
        records
          .filter(record => record.team === group)
          .map(record => record.product),
      ),
    ].map(product => ({
      id: product,
      name: product,
    }));
  }

  async getGroupDailyCost(group: string): Promise<Cost> {
    const records = (await this.records()).filter(
      record => record.team === group,
    );
    return this.toCost(group, records);
  }

  async getProjectDailyCost(project: string): Promise<Cost> {
    const records = (await this.records()).filter(
      record => record.product === project,
    );
    return this.toCost(project, records);
  }

  async getDailyMetricData(metric: string): Promise<MetricData> {
    return {
      id: metric,
      format: 'number',
      aggregation: [],
      change: { amount: 0, ratio: 0 },
    };
  }

  async getProductInsights(options: ProductInsightsOptions): Promise<Entity> {
    const records = (await this.records()).filter(
      record => record.product === options.product,
    );
    const total = records.reduce((sum, record) => sum + record.pretaxCost, 0);
    return {
      id: options.product,
      aggregation: [0, total],
      change: { amount: total, ratio: 0 },
      entities: {},
    };
  }

  async getAlerts(_group: string): Promise<Alert[]> {
    return [];
  }

  private toCost(id: string, records: ShowbackRecord[]): Cost {
    const total = records.reduce((sum, record) => sum + record.pretaxCost, 0);
    const endDate =
      records
        .map(record => record.periodEnd)
        .filter(Boolean)
        .sort()
        .at(-1) ?? new Date().toISOString().slice(0, 10);
    // The showback CSV is a single period snapshot per team/product, not real
    // daily data. Synthesize a daily series by spreading the period total evenly
    // across a fixed window so the Cost Insights overview renders a time series
    // that still sums to the real total, and always provide a trendline (the
    // plugin's chart dereferences trendline.slope without a guard).
    const aggregation = buildSyntheticDailySeries(endDate, total);
    return {
      id,
      aggregation,
      change: changeOf(aggregation),
      trendline: trendlineOf(aggregation),
    };
  }
}

const SHOWBACK_WINDOW_DAYS = 30;

// The showback pipeline emits one cost figure per team/product per period, so
// there is no real daily granularity. This synthesizes a flat daily series from
// the period total purely so the Cost Insights overview chart has a time axis to
// render; the series sums back to the real total and carries no invented trend.
function buildSyntheticDailySeries(
  endDate: string,
  total: number,
): Array<{ date: string; amount: number }> {
  const dailyAmount = total / SHOWBACK_WINDOW_DAYS;
  const end = new Date(`${endDate}T00:00:00Z`);
  const series: Array<{ date: string; amount: number }> = [];
  for (let offset = SHOWBACK_WINDOW_DAYS - 1; offset >= 0; offset -= 1) {
    const day = new Date(end);
    day.setUTCDate(end.getUTCDate() - offset);
    series.push({ date: day.toISOString().slice(0, 10), amount: dailyAmount });
  }
  return series;
}

function changeOf(aggregation: Array<{ date: string; amount: number }>): {
  amount: number;
  ratio: number;
} {
  const first = aggregation.length ? aggregation[0].amount : 0;
  const last = aggregation.length
    ? aggregation[aggregation.length - 1].amount
    : 0;
  return { amount: last - first, ratio: first ? (last - first) / first : 0 };
}

function trendlineOf(aggregation: Array<{ date: string; amount: number }>): {
  slope: number;
  intercept: number;
} {
  const points = aggregation.map(
    entry => [Date.parse(entry.date) / 1000, entry.amount] as const,
  );
  const n = points.length;
  if (n === 0) {
    return { slope: 0, intercept: 0 };
  }
  const sumX = points.reduce((sum, [x]) => sum + x, 0);
  const sumY = points.reduce((sum, [, y]) => sum + y, 0);
  const sumXY = points.reduce((sum, [x, y]) => sum + x * y, 0);
  const sumXX = points.reduce((sum, [x]) => sum + x * x, 0);
  const denominator = n * sumXX - sumX * sumX;
  const slope = denominator === 0 ? 0 : (n * sumXY - sumX * sumY) / denominator;
  const intercept = (sumY - slope * sumX) / n;
  return { slope, intercept };
}
