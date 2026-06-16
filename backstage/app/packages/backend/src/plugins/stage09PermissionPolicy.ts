import { createBackendModule, coreServices } from '@backstage/backend-plugin-api';
import {
  AuthorizeResult,
  isResourcePermission,
  PolicyDecision,
} from '@backstage/plugin-permission-common';
import { RESOURCE_TYPE_CATALOG_ENTITY } from '@backstage/plugin-catalog-common/alpha';
import {
  PermissionPolicy,
  PolicyQuery,
  PolicyQueryUser,
} from '@backstage/plugin-permission-node';
import { policyExtensionPoint } from '@backstage/plugin-permission-node/alpha';
import {
  catalogConditions,
  createCatalogConditionalDecision,
} from '@backstage/plugin-catalog-backend/alpha';

type GroupMappings = {
  platformAdminsGroupRef: string;
  platformOperatorsGroupRef: string;
  applicationTeamGroupRefs: string[];
};

class Stage09PermissionPolicy implements PermissionPolicy {
  constructor(private readonly mappings: GroupMappings) {}

  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser,
  ): Promise<PolicyDecision> {
    const ownershipEntityRefs = user?.info.ownershipEntityRefs ?? [];
    if (!user) {
      return { result: AuthorizeResult.DENY };
    }

    const isAdmin = ownershipEntityRefs.includes(
      this.mappings.platformAdminsGroupRef,
    );
    const isOperator = ownershipEntityRefs.includes(
      this.mappings.platformOperatorsGroupRef,
    );
    const isApplicationTeam = ownershipEntityRefs.some(ref =>
      this.mappings.applicationTeamGroupRefs.includes(ref),
    );
    const permissionName = request.permission.name;

    if (isAdmin) {
      return { result: AuthorizeResult.ALLOW };
    }

    if (permissionName === 'catalog.entity.read') {
      return { result: AuthorizeResult.ALLOW };
    }

    if (permissionName === 'catalog.entity.delete') {
      return { result: AuthorizeResult.DENY };
    }

    if (isOperator && permissionName.startsWith('catalog.entity.')) {
      return { result: AuthorizeResult.ALLOW };
    }

    if (
      isApplicationTeam &&
      permissionName.startsWith('catalog.entity.') &&
      isResourcePermission(request.permission, RESOURCE_TYPE_CATALOG_ENTITY)
    ) {
      return createCatalogConditionalDecision(request.permission, {
        anyOf: [
          catalogConditions.isEntityOwner({
            claims: ownershipEntityRefs,
          }),
        ],
      });
    }

    if (isOperator && permissionName.startsWith('kubernetes.')) {
      return { result: AuthorizeResult.ALLOW };
    }

    if (
      (isOperator || isApplicationTeam) &&
      permissionName.startsWith('scaffolder.')
    ) {
      return { result: AuthorizeResult.ALLOW };
    }

    return { result: AuthorizeResult.DENY };
  }
}

export default createBackendModule({
  pluginId: 'permission',
  moduleId: 'stage09-policy',
  register(reg) {
    reg.registerInit({
      deps: {
        config: coreServices.rootConfig,
        policy: policyExtensionPoint,
      },
      async init({ config, policy }) {
        policy.setPolicy(
          new Stage09PermissionPolicy({
            platformAdminsGroupRef: config.getString(
              'permission.rbac.platformAdminsGroupRef',
            ),
            platformOperatorsGroupRef: config.getString(
              'permission.rbac.platformOperatorsGroupRef',
            ),
            applicationTeamGroupRefs:
              config
                .getOptionalString('permission.rbac.applicationTeamGroupRefs')
                ?.split(',')
                .map(ref => ref.trim())
                .filter(Boolean) ?? [],
          }),
        );
      },
    });
  },
});
