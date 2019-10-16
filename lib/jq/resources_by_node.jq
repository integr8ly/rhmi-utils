import "modules/i8-helpers" as i8;

[.[] | {"key": .id, "value": .result}] | from_entries |
(
  .nodes.items[] |
  {
    name: .metadata.name,
    type: .metadata.labels.type,
    az: (.metadata.labels."failure-domain.beta.kubernetes.io/zone"),
    hostIP: (.status.addresses[] | select(.type=="InternalIP").address)
  }
) as $node | $node + (
  .pods.items[] | select(.status.phase=="Running") | select(.status.hostIP==$node.hostIP) |
  {
    num_containers: i8::sum(.spec.containers | length),
    num_pods: length,
    req_bytes: i8::sum((.spec.containers[].resources.requests.memory | select(.!=null) | i8::mem_to_bytes(.))),
    lim_bytes: i8::sum((.spec.containers[].resources.limits.memory | select(.!=null) | i8::mem_to_bytes(.)))
  }
)

