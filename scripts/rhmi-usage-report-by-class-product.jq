import "i8-helpers" as i8 {"search": ["../lib/jq"]};

def getNamespaceClasses:
  [
    .namespaces[] | {
      ns: .metadata.name,
      labels: .metadata.labels
    } | {
      ns,
      nsClass: (
        if .labels.rhmi=="true" or .labels.integreatly=="true" then
          "rhmi"
        elif .ns=="redhat-rhmi-operator" then
          "rhmi"
        elif .ns | test("^(default|kube-.+)$") then
          #"kube"
          "openshift"
        elif .ns | test("^(openshift.+|operator-lifecycle-manager)$") then
          "openshift"
        elif .ns | test("^(dedicated-(admin|reader)|management-infra|ops-health-monitoring)$") then
          "dedicated"
        else
          "user"
        end
      )
    }
  ];

#
# Tracked products are currently only enmasse, fuse
#
def tagTrackedProduct:
  (.labels?.app? // "") as $app |
  . + (
    if $app=="enmasse" then {
      app: "AMQ",
      type: (.labels?.infraType? // "-"),
      subtype: (.labels?.name? // "-"),
      podClass: (
          if .nsClass=="rhmi" then
            if .labels?.infraUuid? != null then "user"
            else .nsClass
            end
          elif .nsClass=="user" then
            "user"
          else "nsclass: \(.nsClass)"
          end
        )
    }
    elif $app=="syndesis" then {
      app: "Fuse",
      type: (.labels?."syndesis.io/type"? // "-"),
      subtype: (.labels?."syndesis.io/component"? // "-"),
      podClass: (
          if .nsClass=="rhmi" then
            if .labels?."syndesis.io/integration" != null then "user"
            else .nsClass
            end
          elif .nsClass=="user" then
            "user"
          else .nsClass
          end
        )
    }
    else {
      app: "Other",
      type: "",
      subtype: "",
      podClass: .nsClass
    }
    end
  );


def getPodResources:
  [
    .pods[] |
    select(.status.phase=="Running") |
    {
      ns: .metadata.namespace,
      pod: .metadata.name,
      containers: .spec.containers[],
      claims: [.spec.volumes[].persistentVolumeClaim.claimName? // empty],
      labels: (.metadata.labels? // {})
    } | {
      ns,
      pod,
      labels,
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
      containers: .containers[],
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

i8::process |
getNamespaceClasses as $nsClasses |
getPodResources as $pods |
getPodUsages as $usages |
getPVCs as $pvcs |
[i8::leftJoin($pods; $usages; "\(.ns) \(.pod) \(.container)")] as $podsWithUsages |
[i8::leftJoin($podsWithUsages; $nsClasses; "\(.ns)]")] |
map(tagTrackedProduct) |
group_by([.podClass,.app]) |
map(
  {
    podClass: .[0].podClass,
    app: .[0].app,
    cpu_real: [.[].usage.cpu] | add | (if . then .|i8::roundit else . end),
    mem_real: [.[].usage.memory] | add | i8::prettyBytes,
    cpu_req: [.[].requests?.cpu] | add | (if . then .|i8::roundit else . end),
    mem_req: [.[].requests?.memory] | add | i8::prettyBytes,
    cpu_lim: [.[].limits?.cpu] | add | (if . then .|i8::roundit else . end),
    mem_lim: [.[].limits?.memory] | add | i8::prettyBytes,
    storage: [.[0].ns as $ns | $pvcs[] | select(.ns==$ns) | .storage ] | add | i8::prettyBytes
  }
) | (.[0] | to_entries | map(.key)), (.[] | [.[]]) | @tsv
