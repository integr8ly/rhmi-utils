import "i8-helpers" as i8 {"search": ["../lib/jq"]};

def getPodResources:
  [
    .pods[] |
    {
      ns: .metadata.namespace,
      pod: .metadata.name,
      # NOTE: This ends up not including any pods without a parent
      ownerReferenceUid: .metadata.ownerReferences[]? | select(.controller == true).uid,
      containers: .spec.containers[],
      claims: [.spec.volumes[].persistentVolumeClaim.claimName? // empty],
      phase: .status.phase
    } | {
      ns,
      pod,
      container: .containers.name,
      requests: .containers.resources.requests | i8::normalizeResources,
      limits: .containers.resources.limits | i8::normalizeResources,
      claims,
      ownerReferenceUid,
      phase
    }
  ];

def getPodUsages:
  [
    ."pod-metrics"[] | {
    ns: .metadata.namespace,
    pod: .metadata.name,
    containers: .containers[] | select(.metadata.name != "deployment")
  } | {
    ns,
    pod,
    container: .containers.name,
    usage: .containers.usage | i8::normalizeResources
   }
  ];

def getApps:
  [
    .apps[] |
    {
      ns: .metadata.namespace,
      uid: .metadata.uid,
      workloadKind: (if .kind == "StatefulSet" then
        .kind
      elif .kind == "DaemonSet" then
        .kind
      else
        .metadata.ownerReferences[]? | select(.controller == true).kind
      end),
      workloadName: (if .kind == "StatefulSet" then
        .metadata.name
      elif .kind == "DaemonSet" then
        .metadata.name
      else
        .metadata.ownerReferences[]? | select(.controller == true).name
      end),
      workloadReplicas: .spec.replicas
    }
  ];

def getPVCs:
  [
    .volumes[] |
    {
      name: .metadata.name,
      storage: .spec.resources.requests.storage
    }
  ];

i8::process |
getPodResources as $pods |
getPodUsages as $usages |
getApps as $apps |
getPVCs as $pvcs |
[i8::leftJoin($pods; $usages; "\(.ns) \(.pod) \(.container)")] |
map(select(.phase == "Running")) |
map((.ownerReferenceUid as $ownerReferenceUid | $apps[] | select(.uid == $ownerReferenceUid)) as $workload | {
  "Namespace": .ns,
  "Workload Kind": $workload.workloadKind,
  "Workload Name": $workload.workloadName,
  "Workload Replicas": $workload.workloadReplicas,
  "Container Name": .container,
  "CPU - Real": .usage.cpu | (if . then .|i8::roundit else . end),
  "CPU - Requested": .requests?.cpu | (if . then .|i8::roundit else . end),
  "CPU - Limit": .limits?.cpu | (if . then .|i8::roundit else . end),
  "Memory - Real": .usage.memory | i8::prettyBytes,
  "Memory - Requested": .requests?.memory | i8::prettyBytes,
  "Memory - Limit": .limits?.memory | i8::prettyBytes,
  "Pod Claim Storage": (if .claims[0] == null then
                  ""
                else 
                  (.claims[0] as $claimName | $pvcs[] | select(.name == $claimName).storage)
                end)
}) | map(select(.Namespace | contains("redhat-rhmi"))) | (.[0] | to_entries | map(.key)), (.[] | [.[]]) | @csv
