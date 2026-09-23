import {
  configApiRef,
  createFrontendModule,
  githubAuthApiRef,
  useApi,
} from '@backstage/frontend-plugin-api';
import { SignInPageBlueprint } from '@backstage/plugin-app-react';
import { SignInPage } from '@backstage/core-components';

const githubProvider = {
  id: 'github-auth-provider',
  title: 'GitHub',
  message: 'Sign in using GitHub',
  apiRef: githubAuthApiRef,
};

// Replaces the default guest-only sign-in page. GitHub is always offered;
// the guest button is only offered outside `auth.environment: production`
// (auth.providers is backend-only config, auth.environment is frontend-visible).
const signInPage = SignInPageBlueprint.make({
  params: {
    loader: async () => props => {
      const config = useApi(configApiRef);
      const guestEnabled =
        config.getOptionalString('auth.environment') !== 'production';
      return (
        <SignInPage
          {...props}
          providers={
            guestEnabled ? ['guest', githubProvider] : [githubProvider]
          }
        />
      );
    },
  },
});

export const signInModule = createFrontendModule({
  pluginId: 'app',
  extensions: [signInPage],
});
