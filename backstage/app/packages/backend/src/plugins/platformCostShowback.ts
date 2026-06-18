import { createBackendPlugin, coreServices } from '@backstage/backend-plugin-api';
import { DefaultAzureCredential } from '@azure/identity';
import { BlobServiceClient } from '@azure/storage-blob';
import { parse } from 'csv-parse/sync';
import express from 'express';

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

function parseContainerUrl(containerUrl: string) {
  const url = new URL(containerUrl);
  const [, containerName] = url.pathname.split('/');
  if (!containerName) {
    throw new Error('costInsights.azure.showbackContainerUrl must include a container path.');
  }
  return {
    accountUrl: `${url.protocol}//${url.host}`,
    containerName,
  };
}

export default createBackendPlugin({
  pluginId: 'platform-cost-showback',
  register(reg) {
    reg.registerInit({
      deps: {
        config: coreServices.rootConfig,
        httpAuth: coreServices.httpAuth,
        httpRouter: coreServices.httpRouter,
        userInfo: coreServices.userInfo,
      },
      async init({ config, httpAuth, httpRouter, userInfo: userInfoService }) {
        const router = express.Router();
        const containerUrl = config.getOptionalString('costInsights.azure.showbackContainerUrl');
        const admins = new Set(config.getString('permission.rbac.platformAdminsGroupRef').split(',').map(ref => ref.trim()));
        const operators = new Set(config.getString('permission.rbac.platformOperatorsGroupRef').split(',').map(ref => ref.trim()));
        const allowedTeams = new Set(
          config
            .getOptionalString('permission.rbac.applicationTeamGroupRefs')
            ?.split(',')
            .map(ref => ref.trim())
            .filter(Boolean) ?? [],
        );
        const rawTeamGroupMap = config.getOptionalString('permission.rbac.applicationTeamGroupMap') ?? 'json:{}';
        const teamGroupMap = JSON.parse(
          rawTeamGroupMap.startsWith('json:') ? rawTeamGroupMap.slice(5) : rawTeamGroupMap,
        ) as Record<string, string>;
        const containerConfig = containerUrl ? parseContainerUrl(containerUrl) : undefined;
        const container = containerConfig
          ? new BlobServiceClient(
            containerConfig.accountUrl,
            new DefaultAzureCredential(),
          ).getContainerClient(containerConfig.containerName)
          : undefined;

        router.get('/records', async (request, response) => {
          const credentials = await httpAuth.credentials(request, {
            allow: ['user'],
          });
          const callerInfo = await userInfoService.getUserInfo(credentials);
          if (!container) {
            response.json([]);
            return;
          }

          const ownershipRefs = new Set(callerInfo.ownershipEntityRefs);
          const canReadAll = [...admins, ...operators].some(ref => ownershipRefs.has(ref));
          const readableTeams = new Set(
            [...ownershipRefs]
              .filter((ref): ref is string => typeof ref === 'string')
              .filter(ref => allowedTeams.has(ref) && teamGroupMap[ref])
              .map(ref => teamGroupMap[ref]),
          );

          const blobs = [];
          for await (const blob of container.listBlobsFlat()) {
            if (blob.name.endsWith('.csv')) {
              blobs.push(blob);
            }
          }
          blobs.sort((left, right) => {
            const leftTime = left.properties.lastModified?.getTime() ?? 0;
            const rightTime = right.properties.lastModified?.getTime() ?? 0;
            return rightTime - leftTime;
          });

          if (blobs.length === 0) {
            response.json([]);
            return;
          }

          const body = await container.getBlobClient(blobs[0].name).downloadToBuffer();
          const rows = parse(body.toString('utf8'), {
            columns: true,
            skip_empty_lines: true,
          }) as Array<Record<string, string>>;
          const records = rows.map(row => {
            const billingDate = (row.generatedAt ?? '').slice(0, 10);
            return {
              team: row.team,
              product: row.product,
              costCenter: row.costCenter,
              environment: row.environment ?? 'unknown',
              pretaxCost: Number(row.cost),
              currency: 'USD',
              periodStart: billingDate,
              periodEnd: billingDate,
            };
          }).filter(record => canReadAll || readableTeams.has(record.team));
          response.json(records satisfies ShowbackRecord[]);
        });

        httpRouter.use(router);
      },
    });
  },
});
