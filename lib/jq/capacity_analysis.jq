  [[.[] | {"key": .id, "value": (.result.items? // .result)}] | from_entries | . as {pods: $pods, volumes: $vols, "pod-metrics": $podMetrics, nodes: $nodes} |
  (
    $nodes[] | select(.metadata.labels.type == "compute") | 
    {
        name: .metadata.name,
        type: .metadata.labels.type,
        hostIP: (.status.addresses[] | select(.type=="InternalIP").address)
    }
  ) as $node | 
  $pods[] | select(.status.phase=="Running") | select(.status.hostIP==$node.hostIP) |
  {
    node: $node.name,
    type: $node.type,
    pod: .metadata.name, 
    ns: .metadata.namespace, 
    container: .spec.containers[].name,
    requests: .spec.containers[].resources?.requests?,
    limits: .spec.containers[].resources?.limits?
  } as $pod |
  ($podMetrics[] | select(.metadata.name==$pod.pod) | select(.metadata.namespace == $pod.ns) | .containers[] | select(.name == $pod.container)) as $containerMetrics |
  $pod + {
    usage: $containerMetrics.usage
  } | {
  node, type, ns, pod, container,
  cpu_req: normalize_cpu(.requests?.cpu?),
  cpu_lim: normalize_cpu(.limits?.cpu?),
  cpu_real: normalize_cpu(.usage?.cpu?),
  mem_req: (if .requests?.memory? then mem_to_bytes(.requests?.memory?) else null end),
  mem_lim: (if .limits?.memory? then mem_to_bytes(.limits?.memory?) else null end),
  mem_real: (if .usage?.memory? then mem_to_bytes(.usage?.memory?) else null end)
}] | unique
