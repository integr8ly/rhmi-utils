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

i8::process |
getPodResources as $pods |
getPodUsages as $usages |
[i8::leftJoin($pods; $usages; "\(.ns) \(.pod) \(.container)")] |
map({
  ns,
  cpu_real: .usage.cpu,
  mem_real: .usage.memory | i8::prettyBytes,
  cpu_req: .requests?.cpu,
  mem_req: .requests?.memory | i8::prettyBytes,
  cpu_lim: .limits?.cpu,
  mem_lim: .limits?.memory | i8::prettyBytes
})
