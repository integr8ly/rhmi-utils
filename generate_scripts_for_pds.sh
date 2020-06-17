get_user_password() {
  local USER=$1
  local SECRET=$(oc get secret --no-headers -n sso | awk '{print $1}' | egrep "^${USER}(-user)?-credentials$")
  if [ -z ${SECRET} ]
    then
      echo CHANGEME 
  else
    oc get secret ${SECRET} -n sso --no-headers --sort-by .metadata.name --template '{{ printf "%s\n" (.data.password | base64decode) }}' --ignore-not-found
  fi
}

EVAL_USERS_PASS=$(get_user_password evals01)
CUSTOMER_ADMIN_PASS=$(get_user_password customer-admin)
CLUSTER_ADMIN_PASS=$(get_user_password admin)

for PLAYBOOK in install uninstall upgrade; do
  SCRIPT_FILE=${PLAYBOOK}.sh

  cat <<- EOF > ${SCRIPT_FILE}
	ansible-playbook -i inventories/pds.template \\
	  playbooks/${PLAYBOOK}.yml \\
	  -e eval_self_signed_certs=false \\
	  -e rhsso_identity_provider_ca_cert_path= \\
	  -e heimdall=false \\
	  -e amq_streams=true \\
	  -e rhsso_seed_users_password=${EVAL_USERS_PASS} \\
	  -e rhsso_evals_admin_password=${CUSTOMER_ADMIN_PASS} \\
	  -e rhsso_cluster_admin_password=${CLUSTER_ADMIN_PASS} \\
	  -e gitea=false \\
	  -vvv \\
	  | tee -a /tmp/integreatly-${PLAYBOOK}.log
EOF
  chmod +x ${SCRIPT_FILE}
  echo 
  echo A script to run the ${PLAYBOOK} playbook has been written to ${SCRIPT_FILE}.
  echo You can run the script by simply running ./${SCRIPT_FILE} or paste the full command below:
  echo

  cat ${PLAYBOOK}.sh
  
  echo
done
