import "modules/i8-helpers" as i8;

[
  .[] |
  {
    "key": .id,
    "value": (.result.items? // .result)
  }
] | from_entries | 
. as {
  pods: $pods,
  volumes: $vols
} |
[$pods[] | select(.status.phase=="Running")] |
map(
  {
    ns:.metadata.namespace, 
    pod: .metadata.name, 
    containers: [
      .spec.containers[] | {
        container_name: .name,
        rcpu: i8::normalize_cpu(.resources.requests.cpu),
        lcpu: i8::normalize_cpu(.resources.limits.cpu),
        rmem: i8::mem_to_bytes(.resources.requests.memory),
        lmem: i8::mem_to_bytes(.resources.limits.memory)
      }
    ],
    storage: (
      .spec.volumes[].persistentVolumeClaim.claimName as $claim | 
      $vols[] | 
      i8::mem_to_bytes(select(.metadata.name==$claim).status.capacity.storage)
    )
  }
) |
group_by(.ns) | map(
{
  ns: .[0].ns,
  pods: (. | length),
  containers: i8::sum(.[].containers | length),
  rcpu: i8::sum(.[].containers[].rcpu?),
  lcpu: i8::sum(.[].containers[].lcpu?),
  rmem: i8::sum(.[].containers[].rmem?),
  lmem: i8::sum(.[].containers[].lmem?),
  storage: (i8::sum(.[].storage))
})
