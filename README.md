# Akamai Guardicore Kubernetes Orchestration Configuration

### The following instructions should be used in order to configure the K8s Cluster objects required by Akamai's Guardicore Orchestration 
* This `README` relies on running a bash script that automatically deploys all the below objects required by Guardicore and exports the output to be used in Guardicore's UI when configuring the K8s Orchestration.
* If you wish to use the "raw" yaml objects instead of using the bash script, they can be found in the `README_RAW.md` file.
* For Openshift orchestrations the `kubectl` in the script should be replaced with `oc`.
* Note the use of the `<<-` redirector for the here documents. This causes the shell to remove leading `TAB` characters from the here document. Thus, be careful editing this file, as __the YAML configuration files are space sensitive__ and if tabs get replaced with spaces, there will be significant problems!

###The following K8s objects will be created in a dedicated Guardicore namespace:
1. `guardicore-orch` Namespace
2. `gc-reader` ServiceAccount
3. `gc-cluster-reader` ClusterRole
4. `gc-cluster-reader-role-binding` ClusterRoleBinding
5. `gc-secret` ServiceAccount Token


###In order to run the configuration script:

1. Save the file and upload them to a server with sufficient privileges to the cluster's API server.
####
2. Run the following command:
```buildoutcfg
./gc_k8s_orch.sh
```
There is an option to run the command with 2 flags:
```buildoutcfg
./gc_k8s_orch.sh [-c] [-n <orchestration-namepsace> ]
   -c              Print certificate(s)
   -n namespace    Use namespace instead of guardicore-orch


The -c option prints the certificates in addition to the regular output 
(which are not mandatory for orchestration configuration).

The -n option allows changing the orchestration namespace to something
other than "guardicore-orch" (which is the default).
```
####
3. A similar output should be seen
```buildoutcfg
# ./gc_k8s_orch.sh -c
Checking that kubectl exists ... ok
Creating guardicore-orch namespace
namespace/guardicore-orch created
Creating Guardicore service account
serviceaccount/gc-reader created
clusterrole.rbac.authorization.k8s.io/gc-cluster-reader created
clusterrolebinding.rbac.authorization.k8s.io/gc-cluster-reader-role-binding created
Creating service account token
secret/gc-secret created

The following details should be used for configuring this cluster's K8s Orchestration in Akamai Guardicore:

Server IP Address / FQDN and port:
IP Address: api.ocp4....com Port: 6443

Service Account Token (copy/paste):
eyJhb.....qRc

SSL Certificate. If you see more than one, choose any one to use (copy/paste):
-----BEGIN CERTIFICATE-----
MIIDQ.....EeUo=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDT.....tyE=
-----END CERTIFICATE-----
```
####
4. Head over to the Akamai Guardicore UI, and following the deployment guide continue to populate the relevant orchestration fields based on the above outputs

