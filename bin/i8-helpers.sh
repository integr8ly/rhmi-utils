#!/usr/bin/env sh

# Try to execute a `return` statement,
# but do it in a sub-shell and catch the results.
# If this script isn't sourced, that will raise an error.
$(return >/dev/null 2>&1)

# What exit code did that give?
if [ "$?" -ne "0" ]; then
  echo "This script is not sourced."
  echo "This file must be sourced in order to load and use the shell functions contained within."
  exit
fi

#
# Basic helpers
#
i8-pw-generate() {
  < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;
}

i8-project() {
  local ns=$1
  oc project $(i8-resolve-ns $ns)
}

#TODO: This doesn't know how to translate between RHMI 1.x <-> 2.x (i.e. webapp in 1.x -> solution-explorer in 2.x)
i8-resolve-ns() {
  local ns=$1
  oc get ns/{openshift-,,redhat-rhmi-}${ns} --no-headers -o name 2> /dev/null | cut -d/ -f2 | head -n1
}

#
# SSO/admin console functions
#
i8-get-sso-admin() {
   local ns=$(i8-resolve-ns sso)
   oc get secret credential-rhsso -n $ns --template '{{ range $k, $v := .data }}{{ $k }}{{": "}}{{ $v | base64decode}}{{"\n"}}{{end}}' | column -t
}

i8-get-sso-admins() {
  local ns="";
  for i in sso user-sso; do
    ns=$(i8-resolve-ns $i)
    echo -e "\n\n*** ${ns}:"
    oc get secret credential-rhsso -n $ns --template '{{ range $k, $v := .data }}{{ $k }}{{": "}}{{ $v | base64decode}}{{"\n"}}{{end}}' | column -t
    echo
  done
}

i8-get-sso-secret() {
  local ns=$(i8-resolve-ns sso)
  oc get secret openshift-client-client -n $ns --template '{{.data.secret | base64decode }}{{"\n"}}'
}

i8-get-sso-admin-launcher() {
  local ns=$(i8-resolve-ns launcher)
  oc set env dc/launcher-sso -n $ns --list | grep SSO_ADMIN
  oc get route -n $ns launcher-sso --template '{{ printf "SSO_ADMIN_URL=https://%s\n" .spec.host }}'
}

i8-get-sso-admin-3scale() {
  local ns=$(i8-resolve-ns 3scale)
  oc get secret system-seed -n $ns --template '{{ range $k, $v := .data }}{{ $k }}{{": "}}{{ $v | base64decode}}{{"\n"}}{{end}}' | column -t
  oc get route -n $ns --template '{{range .items}}{{ printf "%s: https://%s\n" .spec.to.name .spec.host }}{{end}}' | egrep '^system-[a-z]+' | column -t
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

#TODO: Adding header line even though it doesn't align correctly yet.  Should be easy to do while refactoring out ralign
  echo "NODE                         CPU REQUESTS     CPU LIMITS     MEMORY REQUESTS     MEMORY LIMITS"
  echo $(oc describe node -l ${selector} | egrep '^(Name|  (cpu|memory))') | sed 's/Name/\nName/g' | sed -r 's/(cpu|memory|Name:) /,/g' | ralign | sed 's/)/)\t/g' | sed 's/,//g'
}

#
# Diagnostics/Troubleshooting
#

i8-diag-get-bad-pods() {
# TODO add logic to hide headers when no rows, but include them with rows
  local extra_args=$*
  oc get pods --all-namespaces --sort-by=.metadata.creationTimestamp ${extra_args} | grep -Ev '([0-9]+)/\1|Completed'
}

i8-diag-autofix-pds() {
  local bad_pods_list=$(i8-diag-get-bad-pods --no-headers | tee /dev/tty )

  echo -e "\n\nDeleting all of the pods listed above\n\n"
  echo "${bad_pods_list}" | while read ns pod ignore; do
    oc delete pod $pod -n $ns;
  done

  echo -e "Monitor the status of pods using i8-diag-get-bad-pods until state stabilizes.  Repeat as needed (may need to force restart of postgres pods before others will recover)"
}

i8-get-resources-snapshot() {
  curl https://raw.githubusercontent.com/integr8ly/rhmi-utils/master/support/get-resources.sh | bash
}

i8-get-image-report() {
  local extra_oc_args="$@"
  #echo "Reporting only for current namespace, you can specify additional parameters to pass thru to the oc get such as -n <ns>, --all-namespaces, etc." > /dev/stderr

  oc get sts,deploy,dc -o json ${extra_oc_args} | jq '
    .items | map({
      ns: .metadata.namespace,
      kind,
      name: .metadata.name,
      container: .spec.template.spec.containers[].name,
      image: .spec.template.spec.containers[].image
    })'
}

i8-get-release-version() {
  ns=$(oc get ns --no-headers | awk '{print $1}' | egrep '^((openshift-)?webapp|redhat-rhmi-solution-explorer)$')

  if [[ $ns == redhat-rhmi-solution-explorer ]]; then
      oc get dc/tutorial-web-app -n $ns -o json | jq '
        .spec.template.spec.containers[].env[] |
        select(.name == "INTEGREATLY_VERSION").value
    ' -r
  else
    oc get secret manifest -n $ns -o template='{{(.data.generated_manifest | base64decode) }}' 2> /dev/null |
    jq '.version' -r
  fi
}

