#!/bin/bash

if [ ! -z "$1" ]; then
  tmpdir=$1
else 
  tmpdir=$(mktemp -d)
fi
svr=$(oc whoami --show-server | sed -e 's|^[^/]*//||' -e 's|/.*$||' | cut -d':' -f1)
work_file=${tmpdir}/resources.${svr}.$(TZ=UTC date +%Y%m%d_%H%M%SZ).json

cat << EOF > ${work_file}
[
    {
      "id": "cluster",
      "cmd": "oc whoami --show-server",
      "type": "raw"
    },
    {
      "id": "user",
      "cmd": "oc whoami",
      "type": "raw"
    },
    {
      "id": "date",
      "cmd": "date -u +'%FT%T.%3NZ'",
      "type": "raw"
    },
    {
      "id": "release",
      "cmd": "ns=$(oc get ns --no-headers | awk '{print $1}' | egrep '^((openshift-)?webapp|redhat-rhmi-solution-explorer)$'); (   if [[ \$ns == redhat-rhmi-solution-explorer ]]; then     oc get dc/tutorial-web-app -n \$ns -o json | jq '.spec.template.spec.containers[].env[] | select(.name == \"INTEGREATLY_VERSION\").value' -r;   else      oc get secret manifest -n \$ns -o template='{{(.data.generated_manifest | base64decode) }}' 2> /dev/null | jq '.version' -r;   fi; )",
      "type": "raw"
    },
    {
      "id": "version",
      "cmd": "oc get --raw '/version'",
      "type": "json"
    },
    {
      "id": "namespaces",
      "cmd": "oc get ns -o json",
      "type": "json"
    },
    {
      "id": "pods",
      "cmd": "oc get pod --all-namespaces -o json",
      "type": "json"
    },
    {
      "id": "nodes",
      "cmd": "oc get --raw '/api/v1/nodes'",
      "type": "json"
    },
    {
      "id": "pod-metrics",
      "cmd": "oc get --raw '/apis/metrics.k8s.io/v1beta1/pods'",
      "type": "json"
    },
    {
      "id": "node-metrics",
      "cmd": "oc get --raw '/apis/metrics.k8s.io/v1beta1/nodes'",
      "type": "json"
    },
    {
      "id": "apps",
      "cmd": "oc get $(echo $(oc api-resources --api-group=apps --no-headers | awk '{print $1}') | sed 's/ /,/g' | awk '{print $1",replicationcontrollers"}') --all-namespaces -o json",
      "type": "json"
    },
    {
      "id": "quotas",
      "cmd": "oc get --raw '/apis/quota.openshift.io/v1/clusterresourcequotas'",
      "type": "json"
    },
    {
      "id": "volumes",
      "cmd": "oc get pv,pvc --all-namespaces -o json",
      "type": "json"
    },
    {
      "id": "enmasse-crs",
      "cmd": "(oc get $(echo $(oc api-resources | grep enmasse | awk '{print $1}' | egrep -v '^(addressspaceschemas|addresses)$') | sed 's/ /,/g') --all-namespaces  -o json; oc get addressspaceschemas -o json) | jq 'reduce inputs as \$i (.; .items += \$i.items)'",
      "type": "json"
    },
    {
      "id": "routes",
      "cmd": "oc get routes --all-namespaces -o json",
      "type": "json"
    },
    {
      "id": "services",
      "cmd": "oc get services --all-namespaces -o json",
      "type": "json"
    }
  ]
EOF

cat ${work_file} | jq --arg dir $tmpdir '.[] | "\(.cmd) > \($dir)/\(.id).\(.type)"' -r | bash

for i in ${tmpdir}/*.raw; do
  cat ${work_file} | jq --arg id $(basename $i .raw) --arg x $(cat $i) '[.[] | select(.id==$id).result=$x]' > $work_file.tmp && cp $work_file.tmp ${work_file} && rm $work_file.tmp
done

for i in ${tmpdir}/*.json; do
  cat ${work_file} | jq --arg id $(basename $i .json) --slurpfile x $i '[.[] | select(.id==$id).result=$x[]]' > $work_file.tmp && cp $work_file.tmp ${work_file} && rm $work_file.tmp
done

#rm -r ${tmpdir}

gzip ${work_file} --suffix=.gz

echo "Data for ${svr} has been extracted to ${work_file}.gz"