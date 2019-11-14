import "i8-helpers" as i8 {"search": ["~/.rhmi/utils/lib/jq","~/repos/rhmi-utils/lib/jq"]};

[[.[] | {"key": .id, "value": .result}] | from_entries | .pods.items[] | select(.status.phase=="Running")] | {
    num_containers: i8::sum(.[].spec.containers | length), 
    num_pods: length,
    req_cpus: (i8::sum((.[].spec.containers[].resources.requests.cpu | select(.!=null) | i8::cpu_to_mcores(.))) /1000 | i8::roundit),
    lim_cpus: (i8::sum((.[].spec.containers[].resources.limits.cpu | select(.!=null) | i8::cpu_to_mcores(.))) /1000 | i8::roundit),
    req_gbs: (i8::sum((.[].spec.containers[].resources.requests.memory | select(.!=null) | i8::mem_to_bytes(.))) / 1000000000 | i8::roundit),
    limit_gbs: (i8::sum((.[].spec.containers[].resources.limits.memory | select(.!=null) | i8::mem_to_bytes(.))) / 1000000000 | i8::roundit)
}
