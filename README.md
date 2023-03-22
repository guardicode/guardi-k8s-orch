# Akamai Guardicore Kubernetes Orchestration Configurations

### The following repo contains the yaml files needed to configure Akamai's Guardicore Kubernetes Orchestration.

In order to apply the yamls, either copy the commands or save the yamls and uplaod them to a server with sufficient privileges to the cluster's API server, then run the commands:
#
1. Create a new ‘guardicore-orch’ namespace:
```buildoutcfg
kubectl create ns guardicore-orch
```
#
2. Create a new k8s service account:
```buildoutcfg
kubectl apply -f - <<EOF
apiVersion: v1		
kind: ServiceAccount
metadata:	
  name: gc-reader
  namespace: guardicore-orch
EOF
```
#
3. Create a new cluster role with cluster-wide read privileges:
```buildoutcfg
kubectl apply -f - <<EOF
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
EOF
```
#
**For GKE**: Run the additional step (your_gke_user - guardicore email):
```buildoutcfg
kubectl create clusterrolebinding gc-cluster-admin-binding --clusterrole=cluster-admin --user=<your_gke_user> 
```
#
4. Bind the cluster role ‘cluster-reader’ to the newly created service account:
```buildoutcfg
kubectl apply -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: gc-cluster-reader-role-binding
subjects:
  - kind: ServiceAccount
    name: gc-reader
    namespace: guardicore-orch
roleRef:
  kind: ClusterRole
  name: gc-cluster-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```
#
5. **For K8s v1.24+**: Create a persistent token to the service account:
```buildoutcfg
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: gc-reader-token
  namespace: guardicore-orch
  annotations:
    kubernetes.io/service-account.name: gc-reader
EOF
```
#
6. Get the token associated with the service account (note name of gc-reader-token may differ):
```buildoutcfg
kubectl get secrets -n guardicore-orch | grep gc-reader
```
#
7. Copy the secret output below and save it to be used for the K8s orchestration's configuration in the Guardicore UI:
```buildoutcfg
kubectl describe secret -n guardicore-orch gc-reader-token
```
#
8. **(Optional)** Get the decoded cluster certificate and save a copy to be used for the K8s orchestration's configuration in the Guardicore UI:
* Kubernetes:
```buildoutcfg
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode
```

* GKE/EKS:
CA Certificate can be found under Kubernetes -> Clusters -> Show Credentials

* OpenShift:
Copy the cluster CA certificate. You may receive multiple certificates, pick one.

* OpenShift 3.11:
oc config view --raw | grep certificate-authority-data | cut -f2- -d: | xargs | base64 -d
#
**Save the outputs of the SA secret and certificate, continue configuring the Kubernetes orchestration in the Guardicore UI as instructed in the installation guide.**