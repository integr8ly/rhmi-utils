#
# Basic helpers
#
i8-pw-generate() {
  < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;
}

i8-resolve-ns() {
  local ns=$1
  oc get ns/{openshift-,}${ns} --no-headers -o name 2> /dev/null | cut -d/ -f2 | head -n1
}

#
# SSO functions
#
i8-get-sso-admin() {
   oc get secret credential-rhsso -n $(i8-resolve-ns sso) --template '{{ range $k, $v := .data }}{{ $k }}{{": "}}{{ $v | base64decode}}{{"\n"}}{{end}}' | column -t
}

i8-get-sso-admins() {
  for ns in openshift-{,user-}sso; do
    echo -e "\n\n*** ${ns}:"
    oc get secret credential-rhsso -n $ns --template '{{ range $k, $v := .data }}{{ $k }}{{": "}}{{ $v | base64decode}}{{"\n"}}{{end}}' | column -t
    echo
  done
}

i8-get-sso-secret() {
  oc get secret openshift-client-client -n $(i8-resolve-ns sso) --template '{{.data.secret | base64decode }}{{"\n"}}'
}

i8-get-sso-admin-launcher() {
  oc set env dc/launcher-sso -n $(i8-resolve-ns launcher) --list | grep SSO_ADMIN
  oc get route -n $(i8-resolve-ns launcher) launcher-sso --template '{{ printf "SSO_ADMIN_URL=https://%s\n" .spec.host }}'
}

#
# S3 Backups
#
i8-get-s3-backups() {
  oc get secret -n openshift-integreatly-backups s3-credentials --template '{{ range $k, $v := .data }}export {{ $k }}={{ $v | base64decode}}{{"\n"}}{{end}}'
}

i8-setenv-s3-backups() {
  source <(oc get secret -n openshift-integreatly-backups s3-credentials --template '{{ range $k, $v := .data }}export {{ $k }}={{ $v | base64decode}}{{"\n"}}{{end}}')
}

#
# Resource info extraction
#
i8-get-resources() {
  local ns=${1:-$(oc project -q)}
  (echo -e "pod\tqos\tcontainer\tcpu\tmem" && oc get pod -o json -n $ns | jq '.items[] | {name: .metadata.name, qos: .status.qosClass} as $p | .spec.containers[] | $p + {container: .name, cpu: (.resources.requests.cpu + "-" + .resources.limits.cpu), mem: (.resources.requests.memory + "-" + .resources.limits.memory ) } | [.[]] | @tsv' -r) | column -t
}

# Return list of only middleware namespaces
i8-get-mw-ns() {
  oc get ns -l integreatly-middleware-service=true --no-headers | awk '{print $1}'
}

i8-get-resources-all-ns() {
  local mw_ns_list="$( i8-get-mw-ns )"
  (echo -e "ns\tpod\tqos\tcontainer\tcpu\tmem" && oc get pod -o json --all-namespaces | jq '.items[] | {ns: .metadata.namespace, name: .metadata.name, qos: .status.qosClass} as $p | .spec.containers[] | $p + {container: .name, cpu: (.resources.requests.cpu + "-" + .resources.limits.cpu), mem: (.resources.requests.memory + "-" + .resources.limits.memory ) } | [.[]] | @tsv' -r) | column -t | while read line; do ns=$(echo $line | awk '{print $1}'); if (echo "ns\n${mw_ns_list}" | grep "$ns" > /dev/null); then echo "$line"; fi; done

}

i8-get-pod-resources() {
  (oc get node -l type=compute --no-headers 2> /dev/null; oc get node -l node-role.kubernetes.io/compute=true --no-headers) | while read node stat role age ver; do oc describe node $node | egrep '.+(%.+){3}' | sed -r 's/\(|\)//g' | while read line; do echo $node $line; done; echo ""; done | column -t
}

# TODO Rewrite using printf instead of ralign inner function
i8-get-compute-resources() {
  ralign() (   file="${1:--}";   if [ "$file" = - ]; then     file="$(mktemp)";     cat >"${file}";   fi;   awk '
  FNR == 1 { if (NR == FNR) next }
  NR == FNR {
    for (i = 1; i <= NF; i++) {
      l = length($i)
      if (w[i] < l)
        w[i] = l
    }
    next
  }
  {
    for (i = 1; i <= NF; i++)
      printf "%*s", w[i] + (i > 1 ? 1 : 0), $i
    print ""
  }
  ' "$file" "$file";   if [ "$file" = - ]; then     rm "$file";   fi; )

  local selector=${1:-"type=compute"}

  echo $(oc describe node -l ${selector} | egrep '^(Name|  (cpu|memory))') | sed 's/Name/\nName/g' | sed -r 's/(cpu|memory|Name:) /,/g' | ralign | sed 's/)/)\t/g' | sed 's/,//g'
}

#
# Diagnostics/Troubleshooting
#

i8-diag-get-bad-pods() {
  oc get pods --all-namespaces --sort-by=.metadata.creationTimestamp | grep -Ev '([0-9]+)/\1|Completed'
}
