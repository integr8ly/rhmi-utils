import "i8-helpers" as i8 {"search": ["../lib/jq"]};

def getPodResources:
  [
    .pods[] |
    {
      ns: .metadata.namespace,
      pod: .metadata.name,
      containers: .spec.containers[],
      claims: [.spec.volumes[].persistentVolumeClaim.claimName? // empty]
    } | {
      ns,
      pod,
      container: .containers.name,
      requests: .containers.resources.requests | i8::normalizeResources,
      limits: .containers.resources.limits | i8::normalizeResources,
      claims
    }
  ];

def getPodUsages:
  [
    ."pod-metrics"[] | {
    ns: .metadata.namespace,
    pod: .metadata.name,
    containers: .containers[]
  } | {
    ns,
    pod,
    container: .containers.name,
    usage: .containers.usage | i8::normalizeResources
   }
  ];

def getPVCs:
  .volumes | map({
    ns: .metadata.namespace,
    claim: .metadata.name,
    storage: i8::mem_to_bytes(.status.capacity.storage)
  });
  # | INDEX(.[]; "\(.ns) \(.claim)");

i8::process |
getPodResources as $pods |
getPodUsages as $usages |
getPVCs as $pvcs |
[i8::leftJoin($pods; $usages; "\(.ns) \(.pod) \(.container)")] |
  group_by(.ns) |
  map({
    ns: .[0].ns,
    cpu_real: [.[].usage.cpu] | add,
    mem_real: [.[].usage.memory] | add,
    cpu_req: [.[].requests?.cpu] | add,
    mem_req: [.[].requests?.memory] | add,
    cpu_lim: [.[].limits?.cpu] | add,
    mem_lim: [.[].limits?.memory] | add,
    storage: [.[0].ns as $ns | $pvcs[] | select(.ns==$ns) | .storage ] | add
 })
