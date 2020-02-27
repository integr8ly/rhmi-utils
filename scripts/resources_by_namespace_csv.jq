import "i8-helpers" as i8 {"search": ["../lib/jq"]};

def getPodResources:
  [.pods[] | {
    ns: .metadata.namespace,
    pod: .metadata.name,
    containers: .spec.containers[]
  } | {
    ns,
    pod,
    container: .containers.name,
    requests: .containers.resources.requests | i8::normalizeResources,
    limits: .containers.resources.limits | i8::normalizeResources
  }
  ];

def getPodUsages:
  [."pod-metrics"[] | {
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
  Namespace: .[0].ns,
  "CPU - Real": [.[].usage.cpu] | add | (if . then .|i8::roundit else . end),
  "CPU - Requested": [.[].requests?.cpu] | add | (if . then .|i8::roundit else . end),
  "CPU - Limit": [.[].limits?.cpu] | add | (if . then .|i8::roundit else . end),
  "Memory - Real": [.[].usage.memory] | add,
  "Memory - Requested": [.[].requests?.memory] | add,
  "Memory - Limit": [.[].limits?.memory] | add,
  "Storage": [.[0].ns as $ns | $pvcs[] | select(.ns==$ns) | .storage ] | add
}) | (.[0] | to_entries | map(.key)), (.[] | [.[]]) | @csv