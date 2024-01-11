#! /bin/bash

# This script does as many of the steps for setting up K8S orchestration
# as possible. It must be run on a system with a working kubectl command.

# Note the use of the <<- redirector for the here documents. This causes the
# shell to remove leading TAB characters from the here document. Thus, BE CAREFUL
# editing this file, as the YAML configuration files are *space sensitive* and
# if tabs get replaced with spaces, there will be significant problems!!!

# usage --- print usage message and exit

function usage () {
	printf "usage: $0 [-c] [-n <orchestration-namepsace> ]\n" >&2
	printf "   -c              Print certificate(s)\n" >&2
	printf "   -n namespace    Use namespace instead of guardicore-orch\n" >&2
	exit 1
}

# check_for_kubectl --- make sure we have kubectl

function check_for_kubectl () {
	printf "Checking that kubctl exists ... "
	if (type kubectl > /dev/null 2>&1)
	then
		echo ok		# we're good
	else
		echo " no kubectl command found! Cannot run."
		exit 1
	fi
}

# get_server_version --- extract version in form of 1.20

function get_server_version () {
	# send errors to /dev/null ; --short option is obsolete and the
	# default on newer versions but not on older ones
	kubectl version --short 2>/dev/null |
		awk '/Server/ {
			split($NF, fields, /\./)
			sub(/v/, "", fields[1])
			printf("%s.%s\n", fields[1], fields[2])
		}'
}

# create_namespace -- create the orchestration namespace

function create_namespace () {
	echo Creating guardicore-orch namespace
	kubectl create ns $ORCH_NAMESPACE
}

# create_gc_reader --- create the gc_reader service account

function create_gc_reader () {
	echo Creating Guardicore service account
	kubectl create -f - <<- EOF
		apiVersion: v1
		kind: ServiceAccount
		metadata:
		  name: gc-reader
		  namespace: $ORCH_NAMESPACE
		---
		kind: ClusterRole
		apiVersion: rbac.authorization.k8s.io/v1
		metadata:
		  name: gc-cluster-reader
		rules:
		  - apiGroups: [""]
		    resources:
		      - events
		      - nodes
		      - services
		      - namespaces
		      - replicationcontrollers
		    verbs: ["get", "watch", "list"]
		  - apiGroups: ["apps"]
		    resources:
		      - replicasets
		      - replicasets.apps
		      - replicasets.apps/scale
		      - daemonsets
		      - daemonsets.apps
		      - deployments
		      - deployments.apps
		      - deployments.apps/scale
		      - statefulsets
		      - statefulsets.apps
		      - statefulsets.apps/scale
		    verbs: ["get", "watch", "list"]
		  - apiGroups: ["batch"]
		    resources:
		      - jobs
		      - jobs.batch
		      - cronjobs
		      - cronjobs.batch
		    verbs: ["get", "watch", "list"]
		  - nonResourceURLs: ["*"]
		    verbs: ["get", "watch", "list"]
		---
		kind: ClusterRoleBinding
		apiVersion: rbac.authorization.k8s.io/v1
		metadata:
		  name: gc-cluster-reader-role-binding
		subjects:
		  - kind: ServiceAccount
		    name: gc-reader
		    namespace: $ORCH_NAMESPACE
		roleRef:
		  kind: ClusterRole
		  name: gc-cluster-reader
		  apiGroup: rbac.authorization.k8s.io
	EOF
}

# create_gc_secret --- create the secret; for K8s >= 1.24

function create_gc_secret () {
	echo Creating service account token
	kubectl apply -f - <<- EOF
		apiVersion: v1
		kind: Secret
		metadata:
		  name: gc-secret
		  namespace: $ORCH_NAMESPACE
		  annotations:
		    kubernetes.io/service-account.name: gc-reader
		type: kubernetes.io/service-account-token
	EOF
}


# get_server --- pull out server info from output of 'kubectl config view'

function get_server () {
	local have_server have_name
	local -A servers
	while read line
	do
		case $line in
		"- cluster:"*)
			have_name=false have_server=false
			while read nextline
			do
				case $nextline in
				"server: "*)
					server=$(echo $nextline | sed 's/server: //')
					have_server=true
					;;
				"name: "*)
					name=$(echo $nextline | sed 's/name: //')
					have_name=true
					;;
				esac

				if $have_server && $have_name
				then
					break
				fi
			done
			servers[$name]=$server
			;;
		"current-context: "*)
			desired_server=$(echo $line | sed 's/current-context: //')
			;;
		esac
	done

	if [ "$desired_server" != "" ]
	then
		print_server "${servers[$desired_server]}"
	else
		for i in "${!servers[@]}"
		do
			print_server "${servers[$i]}"
		done
	fi
}

# print_server --- format the server info nicely

function print_server () {
	echo $1 | sed -e 's/:\([0-9][0-9]*\)/ Port: \1/' -e 's;.*https*://;IP Address: ;'

}

# print_server_ip_and_port --- print the server IP address and port number

function print_server_ip_and_port () {
	kubectl config view | get_server
}

# print_certificate --- print the certificate

function print_certificate () {
	kubectl config view --raw --minify \
		--flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' |
		base64 --decode
	echo
}

# print_token --- print the secret

function print_token () {
	kubectl get secret --namespace $ORCH_NAMESPACE -o yaml |
		grep ' token:' | tail -1 | sed 's/^ *token: *//' |
			base64 --decode
	echo
}

# mainline code

ORCH_NAMESPACE=guardicore-orch	# default value
PRINT_CERT=false

while getopts "n:c" option
do
	case $option in
	n)	ORCH_NAMESPACE=$OPTARG
		;;
	c)	PRINT_CERT=true
		;;
	*)	usage
		;;
	esac
done

check_for_kubectl
create_namespace
create_gc_reader

case $(get_server_version) in
1.2[4-9] | 1.[3-9]* | [2-9]*.*)
	create_gc_secret
	;;
esac

echo
echo "The following details should be used for configuring this cluster's K8s Orchestration in Akamai Guardicore:"

echo
echo Server IP Address and port:
print_server_ip_and_port

echo
echo "Service Account Token (copy/paste):"
print_token

if $PRINT_CERT
then
	echo
	echo "SSL Certificate. If you see more than one, choose any one to use (copy/paste):"
	print_certificate
fi
