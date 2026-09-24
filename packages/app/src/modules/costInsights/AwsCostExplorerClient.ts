import {
  Alert,
  Cost,
  CostInsightsApi,
  Entity,
  Group,
  MetricData,
  Project,
} from '@backstage-community/plugin-cost-insights';
import { DiscoveryApi, FetchApi } from '@backstage/frontend-plugin-api';
import { CatalogApi } from '@backstage/plugin-catalog-react';
import { parseEntityRef, stringifyEntityRef } from '@backstage/catalog-model';
import { ResponseError } from '@backstage/errors';

/**
 * Cost Insights client backed by AWS Cost Explorer through the
 * `cost-insights-aws` backend plugin (@aws/cost-insights-plugin-for-backstage-backend).
 *
 * - Teams ("groups") are catalog Group entities the signed-in user belongs to.
 * - Costs of any entity (Group, Component, Resource, System) come from its
 *   `aws.amazon.com/cost-insights-tags` annotation, e.g. `owner=group:default/team-a`.
 * Same behaviour as AWS's legacy frontend client, rewritten for the new frontend system.
 */
export class AwsCostExplorerClient implements CostInsightsApi {
  constructor(
    private readonly discoveryApi: DiscoveryApi,
    private readonly fetchApi: FetchApi,
    private readonly catalogApi: CatalogApi,
  ) {}

  private async get<T>(path: string): Promise<T> {
    const baseUrl = await this.discoveryApi.getBaseUrl('cost-insights-aws');
    const response = await this.fetchApi.fetch(`${baseUrl}/${path}`);
    if (!response.ok) {
      throw await ResponseError.fromResponse(response);
    }
    return response.json();
  }

  async getLastCompleteBillingDate(): Promise<string> {
    // Cost Explorer data for "today" is incomplete; yesterday is the last full day.
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    return yesterday.toISOString().slice(0, 10);
  }

  async getUserGroups(userId: string): Promise<Group[]> {
    const { items } = await this.catalogApi.getEntities({
      filter: {
        kind: 'Group',
        'relations.hasMember': [`user:default/${userId}`],
      },
    });
    return items.map(e => ({
      id: stringifyEntityRef(e),
      name: e.metadata.title ?? e.metadata.name,
    }));
  }

  async getCatalogEntityDailyCost(
    entityRef: string,
    intervals: string,
  ): Promise<Cost> {
    const { namespace, kind, name } = parseEntityRef(entityRef);
    return this.get<Cost>(
      `v1/entity/${namespace}/${kind}/${name}/${encodeURIComponent(intervals)}`,
    );
  }

  async getGroupDailyCost(group: string, intervals: string): Promise<Cost> {
    return this.getCatalogEntityDailyCost(group, intervals);
  }

  async getGroupProjects(_group: string): Promise<Project[]> {
    return [];
  }

  async getAlerts(_group: string): Promise<Alert[]> {
    return [];
  }

  async getDailyMetricData(
    _metric: string,
    _intervals: string,
  ): Promise<MetricData> {
    throw new Error('Business metrics are not configured');
  }

  async getProjectDailyCost(
    _project: string,
    _intervals: string,
  ): Promise<Cost> {
    throw new Error('Projects are not used; costs are per catalog entity');
  }

  async getProductInsights(): Promise<Entity> {
    throw new Error('Product insights are not configured');
  }
}
