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
