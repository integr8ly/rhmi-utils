import "modules/i8-helpers" as i8;

[[.[] | {"key": .id, "value": .result}] | from_entries | .pods.items[] | select(.status.phase=="Running")] | {
    num_containers: sum(.[].spec.containers | length), 
    num_pods: length,
    req_cpus: (sum((.[].spec.containers[].resources.requests.cpu | select(.!=null) | cpu_to_mcores(.))) /1000 | roundit),
    lim_cpus: (sum((.[].spec.containers[].resources.limits.cpu | select(.!=null) | cpu_to_mcores(.))) /1000 | roundit),
    req_gbs: (sum((.[].spec.containers[].resources.requests.memory | select(.!=null) | mem_to_bytes(.))) / 1000000000 | roundit),
    limit_gbs: (sum((.[].spec.containers[].resources.limits.memory | select(.!=null) | mem_to_bytes(.))) / 1000000000 | roundit)
}
