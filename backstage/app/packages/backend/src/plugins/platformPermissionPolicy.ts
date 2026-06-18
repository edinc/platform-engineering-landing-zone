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
  platformRepositoryUrl: string;
  platformRepositoryOwner: string;
  platformRepositoryName: string;
};

type ScaffolderActionCriteria = PermissionCriteria<
  PermissionCondition<'scaffolder-action'>
>;

const teamScopedActionCondition = scaffolderActionConditions.hasStringProperty({
  key: 'values.teamScopedTemplate',
  value: 'true',
});
const goldenPathActionCondition =
  scaffolderActionConditions.hasStringProperty({
    key: 'values.goldenPathTemplate',
    value: 'true',
  });
const teamScopedTemplateActionCondition = {
  anyOf: [teamScopedActionCondition, goldenPathActionCondition] as [
    typeof teamScopedActionCondition,
    typeof goldenPathActionCondition,
  ],
};

const fetchTemplateActionCondition = scaffolderActionConditions.hasActionId({
  actionId: 'fetch:template',
});
const templateSkeletonCondition =
  scaffolderActionConditions.hasStringProperty({
    key: 'url',
    value: './skeleton',
  });
const publishPullRequestActionCondition =
  scaffolderActionConditions.hasActionId({
    actionId: 'publish:github:pull-request',
  });
const platformRepositoryUrlCondition = (repoUrl: string) =>
  scaffolderActionConditions.hasStringProperty({
    key: 'repoUrl',
    value: repoUrl,
  });

function allowTeamScopedFetchFor(
  team: string,
  platformRepositoryOwner: string,
  platformRepositoryName: string,
): ScaffolderActionCriteria {
  const teamNameCondition = scaffolderActionConditions.hasStringProperty({
    key: 'values.teamName',
    value: team,
  });
  const platformRepositoryOwnerCondition =
    scaffolderActionConditions.hasStringProperty({
      key: 'values.platformRepoOwner',
      value: platformRepositoryOwner,
    });
  const platformRepositoryNameCondition =
    scaffolderActionConditions.hasStringProperty({
      key: 'values.platformRepoName',
      value: platformRepositoryName,
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

  const onboardingFetchCondition = {
    allOf: [teamScopedActionCondition, teamNameCondition] as [
      typeof teamScopedActionCondition,
      typeof teamNameCondition,
    ],
  };
  const goldenPathFetchCondition = {
    allOf: [
      goldenPathActionCondition,
      teamNameCondition,
      serviceGoldenPathCondition,
    ] as [
      typeof goldenPathActionCondition,
      typeof teamNameCondition,
      typeof serviceGoldenPathCondition,
    ],
  };

  return {
    allOf: [
      fetchTemplateActionCondition,
      templateSkeletonCondition,
      platformRepositoryOwnerCondition,
      platformRepositoryNameCondition,
      {
        anyOf: [onboardingFetchCondition, goldenPathFetchCondition] as [
          typeof onboardingFetchCondition,
          typeof goldenPathFetchCondition,
        ],
      },
    ] as [
      typeof fetchTemplateActionCondition,
      typeof templateSkeletonCondition,
      typeof platformRepositoryOwnerCondition,
      typeof platformRepositoryNameCondition,
      {
        anyOf: [typeof onboardingFetchCondition, typeof goldenPathFetchCondition];
      },
    ],
  };
}

function allowPlatformPullRequestFor(repoUrl: string, title: string): ScaffolderActionCriteria {
  const titleCondition = scaffolderActionConditions.hasStringProperty({
    key: 'title',
    value: title,
  });

  return {
    allOf: [
      publishPullRequestActionCondition,
      platformRepositoryUrlCondition(repoUrl),
      titleCondition,
    ] as [
      typeof publishPullRequestActionCondition,
      ReturnType<typeof platformRepositoryUrlCondition>,
      typeof titleCondition,
    ],
  };
}

function allowGoldenPathRequestFor(
  repoUrl: string,
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
      platformRepositoryUrlCondition(repoUrl),
      titleCondition,
      branchCondition,
      targetCondition,
    ] as [
      typeof publishPullRequestActionCondition,
      ReturnType<typeof platformRepositoryUrlCondition>,
      typeof titleCondition,
      typeof branchCondition,
      typeof targetCondition,
    ],
  };
}

export class PlatformPermissionPolicy implements PermissionPolicy {
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
      const { platformRepositoryName, platformRepositoryOwner, platformRepositoryUrl } = this.mappings;
      const actionCriteria = [
        allowTeamScopedFetchFor(firstTeam, platformRepositoryOwner, platformRepositoryName),
        allowPlatformPullRequestFor(platformRepositoryUrl, `Onboard ${firstTeam}`),
        allowPlatformPullRequestFor(
          platformRepositoryUrl,
          `Request egress exception for ${firstTeam}`,
        ),
        allowGoldenPathRequestFor(platformRepositoryUrl, firstTeam, 'aks'),
        allowGoldenPathRequestFor(platformRepositoryUrl, firstTeam, 'aca'),
        ...remainingTeams.flatMap(team => [
          allowTeamScopedFetchFor(team, platformRepositoryOwner, platformRepositoryName),
          allowPlatformPullRequestFor(platformRepositoryUrl, `Onboard ${team}`),
          allowPlatformPullRequestFor(
            platformRepositoryUrl,
            `Request egress exception for ${team}`,
          ),
          allowGoldenPathRequestFor(platformRepositoryUrl, team, 'aks'),
          allowGoldenPathRequestFor(platformRepositoryUrl, team, 'aca'),
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
  moduleId: 'platform-policy',
  register(reg) {
    reg.registerInit({
      deps: {
        config: coreServices.rootConfig,
        policy: policyExtensionPoint,
      },
      async init({ config, policy }) {
        policy.setPolicy(
          new PlatformPermissionPolicy({
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
            platformRepositoryUrl: config.getString(
              'permission.rbac.platformRepositoryUrl',
            ),
            platformRepositoryOwner: config.getString(
              'permission.rbac.platformRepositoryOwner',
            ),
            platformRepositoryName: config.getString(
              'permission.rbac.platformRepositoryName',
            ),
          }),
        );
      },
    });
  },
});
