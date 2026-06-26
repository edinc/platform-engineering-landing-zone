import { PlatformCostInsightsClient } from './PlatformCostInsightsClient';
import { DiscoveryApi, FetchApi } from '@backstage/core-plugin-api';

const RECORDS = [
  {
    team: 'platform',
    product: 'platform-core',
    costCenter: 'cc-platform',
    environment: 'demo',
    pretaxCost: 409.46,
    currency: 'USD',
    periodStart: '2026-06-26',
    periodEnd: '2026-06-26',
  },
  {
    team: 'platform',
    product: 'aks-nodes',
    costCenter: 'cc-platform',
    environment: 'demo',
    pretaxCost: 105.24,
    currency: 'USD',
    periodStart: '2026-06-26',
    periodEnd: '2026-06-26',
  },
  {
    team: 'nba-stats',
    product: 'nba-stats',
    costCenter: 'cc-nba-stats',
    environment: 'demo',
    pretaxCost: 277.12,
    currency: 'USD',
    periodStart: '2026-06-26',
    periodEnd: '2026-06-26',
  },
];

function clientWith(records: unknown): PlatformCostInsightsClient {
  const discoveryApi: DiscoveryApi = {
    getBaseUrl: async () => 'http://localhost/api/platform-cost-showback',
  };
  const fetchApi: FetchApi = {
    fetch: (async () => ({
      ok: true,
      json: async () => records,
    })) as unknown as FetchApi['fetch'],
  };
  return new PlatformCostInsightsClient(discoveryApi, fetchApi);
}

describe('PlatformCostInsightsClient', () => {
  it('returns a trendline so the Cost Insights chart does not crash', async () => {
    const client = clientWith(RECORDS);
    const cost = await client.getGroupDailyCost('platform');

    // The cost-insights overview chart dereferences trendline.slope without a
    // guard, so the client must always provide a defined trendline.
    expect(cost.trendline).toBeDefined();
    expect(typeof cost.trendline!.slope).toBe('number');
    expect(Number.isFinite(cost.trendline!.slope)).toBe(true);
    expect(Number.isFinite(cost.trendline!.intercept)).toBe(true);
  });

  it('spreads the period total across a daily series that sums to the team total', async () => {
    const client = clientWith(RECORDS);
    const cost = await client.getGroupDailyCost('platform');

    expect(cost.aggregation.length).toBeGreaterThan(1);
    const sum = cost.aggregation.reduce(
      (total, entry) => total + entry.amount,
      0,
    );
    expect(sum).toBeCloseTo(409.46 + 105.24, 2);
    // Every day in the window carries a positive share of the cost.
    expect(cost.aggregation.every(entry => entry.amount > 0)).toBe(true);
  });

  it('derives groups and projects from the showback records', async () => {
    const client = clientWith(RECORDS);

    const groups = await client.getUserGroups('user:default/example');
    expect(groups.map(group => group.id).sort()).toEqual([
      'nba-stats',
      'platform',
    ]);

    const projects = await client.getGroupProjects('platform');
    expect(projects.map(project => project.id).sort()).toEqual([
      'aks-nodes',
      'platform-core',
    ]);
  });

  it('returns an empty, non-crashing cost when a team has no records', async () => {
    const client = clientWith([]);
    const cost = await client.getGroupDailyCost('platform');

    expect(cost.trendline).toBeDefined();
    expect(Number.isFinite(cost.trendline!.slope)).toBe(true);
    const sum = cost.aggregation.reduce(
      (total, entry) => total + entry.amount,
      0,
    );
    expect(sum).toBe(0);
  });
});
