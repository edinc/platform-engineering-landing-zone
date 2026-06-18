import { AuthorizeResult } from '@backstage/plugin-permission-common';
import {
  actionExecutePermission,
  taskCreatePermission,
} from '@backstage/plugin-scaffolder-common/alpha';
import { PolicyQuery, PolicyQueryUser } from '@backstage/plugin-permission-node';
import { PlatformPermissionPolicy } from './platformPermissionPolicy';

const policy = new PlatformPermissionPolicy({
  platformAdminsGroupRef: 'group:default/pe-platform-admins',
  platformOperatorsGroupRef: 'group:default/pe-platform-operators',
  applicationTeamGroupRefs: ['group:default/pe-app-team-payments'],
  applicationTeamGroupMap: {
    'group:default/pe-app-team-payments': 'payments',
  },
  platformRepositoryUrl: 'github.com?owner=customer-org&repo=platform-engineering-landing-zone',
  platformRepositoryOwner: 'customer-org',
  platformRepositoryName: 'platform-engineering-landing-zone',
});

const paymentsUser = {
  info: {
    userEntityRef: 'user:default/alice',
    ownershipEntityRefs: ['group:default/pe-app-team-payments'],
  },
} as PolicyQueryUser;

describe('PlatformPermissionPolicy scaffolder authorization', () => {
  it('allows app-team users to create scaffolder tasks', async () => {
    await expect(
      policy.handle({ permission: taskCreatePermission } as PolicyQuery, paymentsUser),
    ).resolves.toEqual({ result: AuthorizeResult.ALLOW });
  });

  it('returns a team-scoped action decision for mapped app-team users', async () => {
    const decision = await policy.handle(
      { permission: actionExecutePermission } as PolicyQuery,
      paymentsUser,
    );

    expect(decision.result).toBe(AuthorizeResult.CONDITIONAL);
    expect(JSON.stringify(decision)).toContain('payments');
    expect(JSON.stringify(decision)).not.toContain('orders');
  });

  it('denies app-team action execution when the group-to-team map is missing', async () => {
    const unmappedPolicy = new PlatformPermissionPolicy({
      platformAdminsGroupRef: 'group:default/pe-platform-admins',
      platformOperatorsGroupRef: 'group:default/pe-platform-operators',
      applicationTeamGroupRefs: ['group:default/pe-app-team-payments'],
      applicationTeamGroupMap: {},
      platformRepositoryUrl: 'github.com?owner=customer-org&repo=platform-engineering-landing-zone',
      platformRepositoryOwner: 'customer-org',
      platformRepositoryName: 'platform-engineering-landing-zone',
    });

    await expect(
      unmappedPolicy.handle(
        { permission: actionExecutePermission } as PolicyQuery,
        paymentsUser,
      ),
    ).resolves.toEqual({ result: AuthorizeResult.DENY });
  });
});
