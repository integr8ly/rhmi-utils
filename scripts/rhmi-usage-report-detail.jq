import "i8-helpers" as i8 {"search": ["../lib/jq"]};
import "rhmi-usage-common" as ruc {"search": ["../lib/jq"]};

i8::process |
ruc::getNamespaceClasses as $nsClasses |
ruc::getPodResources as $pods |
ruc::getPodUsages as $usages |
ruc::getPVCs as $pvcs |
[i8::leftJoin($pods; $usages; "\(.ns) \(.pod) \(.container)")] as $podsWithUsages |
[i8::leftJoin($podsWithUsages; $nsClasses; "\(.ns)]")] |
map(ruc::tagTrackedProduct) |
sort_by([.podClass,.nsClass]) |
map(
  {
    podClass,
    nsClass,
    ns,
    app,
    type,
    subtype,
    pod,
    container,
    cpu_real: .usage.cpu,
    mem_real: .usage.memory,
    cpu_req: .requests?.cpu,
    mem_req: .requests?.memory,
    cpu_lim: .limits?.cpu,
    mem_lim: .limits?.memory,
    storage: [.ns as $ns | $pvcs[] | select(.ns==$ns) | .storage ] | add
  }
) | (.[0] | to_entries | map(.key)), (.[] | [.[]]) | @tsv
