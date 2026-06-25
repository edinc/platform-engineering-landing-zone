import {
  convertLegacyPageExtension,
  convertLegacyAppOptions,
  convertLegacyPlugin,
} from '@backstage/core-compat-api';
import {
  configApiRef,
  createApiFactory,
  discoveryApiRef,
  fetchApiRef,
  microsoftAuthApiRef,
} from '@backstage/core-plugin-api';
import { SignInPage } from '@backstage/core-components';
import { createApp } from '@backstage/frontend-defaults';
import apiDocsPlugin from '@backstage/plugin-api-docs/alpha';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import catalogImportPlugin from '@backstage/plugin-catalog-import/alpha';
import {
  EntityGithubActionsContent,
  githubActionsPlugin,
} from '@backstage/plugin-github-actions';
import kubernetesPlugin from '@backstage/plugin-kubernetes/alpha';
import notificationsPlugin from '@backstage/plugin-notifications/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';
import signalsPlugin from '@backstage/plugin-signals/alpha';
import techdocsPlugin from '@backstage/plugin-techdocs/alpha';
import {
  CostInsightsPage,
  costInsightsApiRef,
  costInsightsPlugin,
} from '@backstage-community/plugin-cost-insights';
import {
  FluxRuntimePage,
  fluxPlugin,
} from '@backstage-community/plugin-flux';
import { navModule } from './modules/nav';
import { PlatformCostInsightsClient } from './apis/PlatformCostInsightsClient';

const githubActionsFeature = convertLegacyPlugin(githubActionsPlugin, {
  extensions: [
    convertLegacyPageExtension(EntityGithubActionsContent, {
      path: '/github-actions',
    }),
  ],
});

const fluxFeature = convertLegacyPlugin(fluxPlugin, {
  extensions: [
    convertLegacyPageExtension(FluxRuntimePage, {
      path: '/flux',
    }),
  ],
});

const costInsightsFeature = convertLegacyPlugin(costInsightsPlugin, {
  extensions: [
    convertLegacyPageExtension(CostInsightsPage, {
      path: '/cost-insights',
    }),
  ],
});

export default createApp({
  features: [
    apiDocsPlugin,
    catalogPlugin,
    catalogImportPlugin,
    costInsightsFeature,
    convertLegacyAppOptions({
      components: {
        SignInPage: props => (
          <SignInPage
            {...props}
            provider={{
              id: 'microsoft-auth-provider',
              title: 'Microsoft Entra ID',
              message: 'Sign in with your Microsoft Entra account',
              apiRef: microsoftAuthApiRef,
            }}
          />
        ),
      },
      apis: [
        createApiFactory({
          api: costInsightsApiRef,
          deps: {
            configApi: configApiRef,
            discoveryApi: discoveryApiRef,
            fetchApi: fetchApiRef,
          },
          factory: ({ discoveryApi, fetchApi }) =>
            new PlatformCostInsightsClient(discoveryApi, fetchApi),
        }),
      ],
    }),
    fluxFeature,
    githubActionsFeature,
    kubernetesPlugin,
    notificationsPlugin,
    scaffolderPlugin,
    signalsPlugin,
    techdocsPlugin,
    navModule,
  ],
});
