import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import { navModule } from './modules/nav';
import { homeModule } from './modules/home';
import { signInModule } from './modules/signIn';
import { amazonEcsModule } from './modules/amazonEcs';
import { costInsightsModule } from './modules/costInsights';

export default createApp({
  features: [
    catalogPlugin,
    navModule,
    homeModule,
    signInModule,
    amazonEcsModule,
    costInsightsModule,
  ],
});
