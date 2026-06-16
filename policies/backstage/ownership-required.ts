export type BackstageEntity = {
  kind?: string;
  metadata?: {
    name?: string;
    namespace?: string;
  };
  spec?: {
    owner?: string;
  };
};

export type OwnershipViolation = {
  entityRef: string;
  message: string;
};

const OWNER_REF_PATTERN =
  /^(group|user):default\/[a-z0-9][a-z0-9_.-]{1,62}[a-z0-9]$/;

export function validateOwnershipRequired(
  entity: BackstageEntity,
): OwnershipViolation[] {
  if (entity.kind !== 'Component') {
    return [];
  }

  const owner = entity.spec?.owner;
  if (!owner || !OWNER_REF_PATTERN.test(owner)) {
    const namespace = entity.metadata?.namespace ?? 'default';
    const name = entity.metadata?.name ?? 'unknown';
    return [
      {
        entityRef: `component:${namespace}/${name}`,
        message:
          'Backstage Component entities must set spec.owner to a synced Entra group or user ref.',
      },
    ];
  }

  return [];
}

export function assertOwnershipRequired(entities: BackstageEntity[]) {
  const violations = entities.flatMap(validateOwnershipRequired);
  if (violations.length > 0) {
    throw new Error(
      violations
        .map(violation => `${violation.entityRef}: ${violation.message}`)
        .join('\n'),
    );
  }
}
