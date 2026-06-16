import { AuthorizeResult } from '@backstage/plugin-permission-common';
import {
  actionExecutePermission,
  taskCreatePermission,
} from '@backstage/plugin-scaffolder-common/alpha';
import { PolicyQuery, PolicyQueryUser } from '@backstage/plugin-permission-node';
import { Stage09PermissionPolicy } from './stage09PermissionPolicy';

const policy = new Stage09PermissionPolicy({
  platformAdminsGroupRef: 'group:default/pe-platform-admins',
  platformOperatorsGroupRef: 'group:default/pe-platform-operators',
  applicationTeamGroupRefs: ['group:default/pe-app-team-payments'],
  applicationTeamGroupMap: {
    'group:default/pe-app-team-payments': 'payments',
  },
});

const paymentsUser = {
  info: {
    userEntityRef: 'user:default/alice',
    ownershipEntityRefs: ['group:default/pe-app-team-payments'],
  },
} as PolicyQueryUser;

describe('Stage09PermissionPolicy Stage 10 scaffolder authorization', () => {
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
    const unmappedPolicy = new Stage09PermissionPolicy({
      platformAdminsGroupRef: 'group:default/pe-platform-admins',
      platformOperatorsGroupRef: 'group:default/pe-platform-operators',
      applicationTeamGroupRefs: ['group:default/pe-app-team-payments'],
      applicationTeamGroupMap: {},
    });

    await expect(
      unmappedPolicy.handle(
        { permission: actionExecutePermission } as PolicyQuery,
        paymentsUser,
      ),
    ).resolves.toEqual({ result: AuthorizeResult.DENY });
  });
});
