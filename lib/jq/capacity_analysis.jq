def pow(n):
  if n == 0 then 1
  elif . == 0 then 0
  else ( (n | floor) == n) as $intp
       | ( (n % 2) | if . == 0 then 1 else -1 end ) as $sign
       | if . == -1 and $intp then $sign
         elif . < 0 then -(.) | pow(n) * $sign
         elif $intp and n > 0 then . * pow(n - 1)
         else log * n | exp
         end
  end;

def mem_to_bytes(v):
  if (v | type != "string") then v else
  v
  | capture("(?<n>[0-9]+)(?<u>[A-Z])(?<i>i|)") as $in
  | (if ($in.i=="i") then 1024 else 1000 end) as $mod
  | (("BKMGTPEZY" | index($in.u))) as $power
  | (($mod | pow($power)) * ($in.n | tonumber))
  end;

def sum(s): reduce s as $x (null; . + $x ); 

def cpu_to_mcores($v):
  if (v | type != "string") then v else
    if (v | endswith("m")) then
      (v[:-1]|tonumber) 
    else 
      (((v|tonumber)*1000))
    end
  end; 

def normalize_cpu(v):
  if (v == "0") then 0 else
  if (v | type != "string") then v else
    if (v | endswith("m")) then
      (v[:-1]|tonumber)/1000
    else
      (v|tonumber)
    end
  end
  end;



def roundit: .*100.0 + 0.5|floor/100.0;


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
