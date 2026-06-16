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
    const baseUrl = await this.discoveryApi.getBaseUrl('platform-cost-showback');
    const response = await this.fetchApi.fetch(`${baseUrl}/records`);
    if (!response.ok) {
      throw new Error(`Failed to load platform cost showback: ${response.status}`);
    }
    return response.json() as Promise<ShowbackRecord[]>;
  }

  async getLastCompleteBillingDate(): Promise<string> {
    const records = await this.records();
    return records.map(record => record.periodEnd).sort().at(-1) ?? new Date().toISOString().slice(0, 10);
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
    return [...new Set(records.filter(record => record.team === group).map(record => record.product))].map(product => ({
      id: product,
      name: product,
    }));
  }

  async getGroupDailyCost(group: string): Promise<Cost> {
    const records = (await this.records()).filter(record => record.team === group);
    return this.toCost(group, records);
  }

  async getProjectDailyCost(project: string): Promise<Cost> {
    const records = (await this.records()).filter(record => record.product === project);
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
    const records = (await this.records()).filter(record => record.product === options.product);
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
    const byDate = new Map<string, number>();
    for (const record of records) {
      byDate.set(record.periodEnd, (byDate.get(record.periodEnd) ?? 0) + record.pretaxCost);
    }
    return {
      id,
      aggregation: [...byDate.entries()].sort(([left], [right]) => left.localeCompare(right)).map(([date, amount]) => ({
        date,
        amount,
      })),
      change: { amount: records.reduce((sum, record) => sum + record.pretaxCost, 0), ratio: 0 },
    };
  }
}
