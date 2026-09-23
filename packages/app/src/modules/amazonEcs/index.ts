import { convertLegacyPlugin } from '@backstage/core-compat-api';
import { convertLegacyEntityContentExtension } from '@backstage/plugin-catalog-react/alpha';
import {
  amazonEcsPlugin,
  EntityAmazonEcsServicesContent,
  isAmazonEcsServiceAvailable,
} from '@aws/amazon-ecs-plugin-for-backstage';

// The AWS ECS plugin only ships a legacy frontend; convert it (and its API
// client) for the new frontend system and add an "Amazon ECS" entity tab,
// shown for entities annotated with aws.amazon.com/amazon-ecs-service-arn.
export const amazonEcsModule = convertLegacyPlugin(amazonEcsPlugin, {
  extensions: [
    convertLegacyEntityContentExtension(EntityAmazonEcsServicesContent, {
      name: 'amazon-ecs',
      path: '/ecs',
      title: 'Amazon ECS',
      filter: isAmazonEcsServiceAvailable,
    }),
  ],
});
