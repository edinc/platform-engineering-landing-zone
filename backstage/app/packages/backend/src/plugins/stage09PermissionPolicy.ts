import { createBackendModule, coreServices } from '@backstage/backend-plugin-api';
import {
  AuthorizeResult,
  isPermission,
  isResourcePermission,
  PermissionCondition,
  PermissionCriteria,
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
import {
  actionExecutePermission,
  taskCancelPermission,
  taskCreatePermission,
  taskReadPermission,
  templateParameterReadPermission,
  templateStepReadPermission,
} from '@backstage/plugin-scaffolder-common/alpha';
import {
  createScaffolderActionConditionalDecision,
  createScaffolderTaskConditionalDecision,
  createScaffolderTemplateConditionalDecision,
  scaffolderActionConditions,
  scaffolderTaskConditions,
  scaffolderTemplateConditions,
} from '@backstage/plugin-scaffolder-backend/alpha';

type GroupMappings = {
  platformAdminsGroupRef: string;
  platformOperatorsGroupRef: string;
  applicationTeamGroupRefs: string[];
  applicationTeamGroupMap: Record<string, string>;
};

type ScaffolderActionCriteria = PermissionCriteria<
  PermissionCondition<'scaffolder-action'>
>;

const teamScopedActionCondition = scaffolderActionConditions.hasStringProperty({
  key: 'values.stage10TeamScoped',
  value: 'true',
});
const stage11GoldenPathActionCondition =
  scaffolderActionConditions.hasStringProperty({
    key: 'values.stage11GoldenPath',
    value: 'true',
  });
const teamScopedTemplateActionCondition = {
  anyOf: [teamScopedActionCondition, stage11GoldenPathActionCondition] as [
    typeof teamScopedActionCondition,
    typeof stage11GoldenPathActionCondition,
  ],
};

const fetchTemplateActionCondition = scaffolderActionConditions.hasActionId({
  actionId: 'fetch:template',
});
const stage10TemplateSkeletonCondition =
  scaffolderActionConditions.hasStringProperty({
    key: 'url',
    value: './skeleton',
  });
const publishPullRequestActionCondition =
  scaffolderActionConditions.hasActionId({
    actionId: 'publish:github:pull-request',
  });
const platformRepositoryUrlCondition =
  scaffolderActionConditions.hasStringProperty({
    key: 'repoUrl',
    value: 'github.com?owner=edinc&repo=platform-engineering-landing-zone',
  });

function allowTeamScopedFetchFor(team: string): ScaffolderActionCriteria {
  const teamNameCondition = scaffolderActionConditions.hasStringProperty({
    key: 'values.teamName',
    value: team,
  });
  const serviceGoldenPathCondition = {
    anyOf: [
      scaffolderActionConditions.hasStringProperty({
        key: 'values.goldenPathType',
        value: 'aks-microservice',
      }),
      scaffolderActionConditions.hasStringProperty({
        key: 'values.goldenPathType',
        value: 'aca-service',
      }),
    ] as [
      ReturnType<typeof scaffolderActionConditions.hasStringProperty>,
      ReturnType<typeof scaffolderActionConditions.hasStringProperty>,
    ],
  };

  const stage10FetchCondition = {
    allOf: [teamScopedActionCondition, teamNameCondition] as [
      typeof teamScopedActionCondition,
      typeof teamNameCondition,
    ],
  };
  const stage11ServiceFetchCondition = {
    allOf: [
      stage11GoldenPathActionCondition,
      teamNameCondition,
      serviceGoldenPathCondition,
    ] as [
      typeof stage11GoldenPathActionCondition,
      typeof teamNameCondition,
      typeof serviceGoldenPathCondition,
    ],
  };

  return {
    allOf: [
      fetchTemplateActionCondition,
      stage10TemplateSkeletonCondition,
      {
        anyOf: [stage10FetchCondition, stage11ServiceFetchCondition] as [
          typeof stage10FetchCondition,
          typeof stage11ServiceFetchCondition,
        ],
      },
    ] as [
      typeof fetchTemplateActionCondition,
      typeof stage10TemplateSkeletonCondition,
      {
        anyOf: [typeof stage10FetchCondition, typeof stage11ServiceFetchCondition];
      },
    ],
  };
}

function allowPlatformPullRequestFor(title: string): ScaffolderActionCriteria {
  const titleCondition = scaffolderActionConditions.hasStringProperty({
    key: 'title',
    value: title,
  });

  return {
    allOf: [
      publishPullRequestActionCondition,
      platformRepositoryUrlCondition,
      titleCondition,
    ] as [
      typeof publishPullRequestActionCondition,
      typeof platformRepositoryUrlCondition,
      typeof titleCondition,
    ],
  };
}

function allowGoldenPathRequestFor(
  team: string,
  kind: 'aks' | 'aca',
): ScaffolderActionCriteria {
  const titleCondition = scaffolderActionConditions.hasStringProperty({
    key: 'title',
    value: `Create ${kind === 'aks' ? 'AKS microservice' : 'ACA service'} for ${team}`,
  });
  const branchCondition = scaffolderActionConditions.hasStringProperty({
    key: 'branchName',
    value: `golden-path-${kind}-${team}`,
  });
  const targetCondition = scaffolderActionConditions.hasStringProperty({
    key: 'targetPath',
    value: `golden-path-requests/${kind}/${team}`,
  });

  return {
    allOf: [
      publishPullRequestActionCondition,
      platformRepositoryUrlCondition,
      titleCondition,
      branchCondition,
      targetCondition,
    ] as [
      typeof publishPullRequestActionCondition,
      typeof platformRepositoryUrlCondition,
      typeof titleCondition,
      typeof branchCondition,
      typeof targetCondition,
    ],
  };
}

export class Stage09PermissionPolicy implements PermissionPolicy {
  constructor(private readonly mappings: GroupMappings) {}

  private teamNamesFor(ownershipEntityRefs: string[]) {
    return ownershipEntityRefs
      .filter(ref => this.mappings.applicationTeamGroupRefs.includes(ref))
      .map(ref => this.mappings.applicationTeamGroupMap[ref])
      .filter((team): team is string => Boolean(team));
  }

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
    const applicationTeamNames = this.teamNamesFor(ownershipEntityRefs);
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
      isPermission(request.permission, templateParameterReadPermission) ||
      isPermission(request.permission, templateStepReadPermission)
    ) {
      if (isApplicationTeam) {
        return createScaffolderTemplateConditionalDecision(request.permission, {
          anyOf: [
            {
              not: scaffolderTemplateConditions.hasTag({
                tag: 'platform-admin-only',
              }),
            },
          ],
        });
      }
      if (isOperator) {
        return createScaffolderTemplateConditionalDecision(request.permission, {
          allOf: [
            {
              not: scaffolderTemplateConditions.hasTag({
                tag: 'team-scoped',
              }),
            },
            {
              not: scaffolderTemplateConditions.hasTag({
                tag: 'platform-admin-only',
              }),
            },
          ],
        });
      }
    }

    if (
      isPermission(request.permission, actionExecutePermission) &&
      isApplicationTeam
    ) {
      if (applicationTeamNames.length === 0) {
        return { result: AuthorizeResult.DENY };
      }

      const [firstTeam, ...remainingTeams] = applicationTeamNames;
      const actionCriteria = [
        allowTeamScopedFetchFor(firstTeam),
        allowPlatformPullRequestFor(`Onboard ${firstTeam}`),
        allowPlatformPullRequestFor(
          `Request egress exception for ${firstTeam}`,
        ),
        allowGoldenPathRequestFor(firstTeam, 'aks'),
        allowGoldenPathRequestFor(firstTeam, 'aca'),
        ...remainingTeams.flatMap(team => [
          allowTeamScopedFetchFor(team),
          allowPlatformPullRequestFor(`Onboard ${team}`),
          allowPlatformPullRequestFor(
            `Request egress exception for ${team}`,
          ),
          allowGoldenPathRequestFor(team, 'aks'),
          allowGoldenPathRequestFor(team, 'aca'),
        ]),
      ] as [ScaffolderActionCriteria, ...ScaffolderActionCriteria[]];

      return createScaffolderActionConditionalDecision(request.permission, {
        anyOf: actionCriteria,
      });
    }

    if (isPermission(request.permission, actionExecutePermission) && isOperator) {
      return createScaffolderActionConditionalDecision(request.permission, {
        not: teamScopedTemplateActionCondition,
      });
    }

    if (
      isPermission(request.permission, taskCreatePermission) &&
      (isOperator || isApplicationTeam)
    ) {
      return { result: AuthorizeResult.ALLOW };
    }

    if (
      (isPermission(request.permission, taskReadPermission) ||
        isPermission(request.permission, taskCancelPermission)) &&
      isOperator
    ) {
      return { result: AuthorizeResult.ALLOW };
    }

    if (
      (isPermission(request.permission, taskReadPermission) ||
        isPermission(request.permission, taskCancelPermission)) &&
      isApplicationTeam
    ) {
      return createScaffolderTaskConditionalDecision(request.permission, {
        anyOf: [
          scaffolderTaskConditions.isTaskOwner({
            createdBy: [user.info.userEntityRef],
          }),
        ],
      });
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
            applicationTeamGroupMap: JSON.parse(
              (
                config.getOptionalString(
                  'permission.rbac.applicationTeamGroupMap',
                ) || 'json:{}'
              ).replace(/^json:/, ''),
            ) as Record<string, string>,
          }),
        );
      },
    });
  },
});
