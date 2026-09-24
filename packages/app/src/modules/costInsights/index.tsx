import {
  ApiBlueprint,
  createFrontendModule,
  discoveryApiRef,
  fetchApiRef,
} from '@backstage/frontend-plugin-api';
import { catalogApiRef } from '@backstage/plugin-catalog-react';
import { convertLegacyEntityContentExtension } from '@backstage/plugin-catalog-react/alpha';
import {
  costInsightsApiRef,
  EntityCostInsightsContent,
} from '@backstage-community/plugin-cost-insights';
import { AwsCostExplorerClient } from './AwsCostExplorerClient';

const COST_TAGS_ANNOTATION = 'aws.amazon.com/cost-insights-tags';

// Extends the community Cost Insights plugin (auto-discovered, /cost-insights page):
//  - replaces its example API (fake data) with real AWS Cost Explorer data
//  - adds a "Costs" tab to catalog entities that declare which AWS tags they own
export const costInsightsModule = createFrontendModule({
  pluginId: 'cost-insights',
  extensions: [
    ApiBlueprint.make({
      params: defineParams =>
        defineParams({
          api: costInsightsApiRef,
          deps: {
            discoveryApi: discoveryApiRef,
            fetchApi: fetchApiRef,
            catalogApi: catalogApiRef,
          },
          factory: ({ discoveryApi, fetchApi, catalogApi }) =>
            new AwsCostExplorerClient(discoveryApi, fetchApi, catalogApi),
        }),
    }),
    convertLegacyEntityContentExtension(EntityCostInsightsContent, {
      name: 'aws-costs',
      path: '/costs',
      title: 'Costs',
      filter: entity =>
        Boolean(entity.metadata.annotations?.[COST_TAGS_ANNOTATION]),
    }),
  ],
});
