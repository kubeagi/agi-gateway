## Kubebb Deploys Gateway API Components

### Prerequisite dependency

The following components have been deployed in the cluster：

- u4a-component
- logging-component
- monitor-component


## Manage cluster installation
- Deploy minio first, then deploy gateway-management、tamp-portal

### Create namespace
```
kubectl --as=admin --as-group=iam.tenxcloud.com create -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
     capsule.clastix.io/tenant: system-tenant
  name: tamp-system
EOF
```
### Create configmap
```
kubectl create cm tamp-anywhere-helm-values --from-file=values-minio.yaml=gateway-api/values-minio.yaml --from-file=values.yaml=gateway-api/values.yaml -n kubebb-system
```
###  Query minio information for API documentation of gateway components
```
kubectl get pod -nkubeagi-system
```
If there is a record of this pod running in the results, it can be used,for example:
```
arcadia-minio-7469c6dcfb-nb6q4                                    1/1     Running     1             48d
```
View minio's SVC
```
kubectl get svc -nkubeagi-system
```
Then we need to check his username and password
```
kubectl get secret -nkubeagi-system  arcadia-minio  -oyaml
```
View the following two values as username and password,The later configuration will use
- rootPassword
- rootUser


### Install gateway-management and tamp-portal
- Modify componentplan.yaml according to the actual situation, as follows:
```
  override:
    set:
      - global.minio.key=admin # minio的key
      - global.minio.secret=Passw0rd! # minio的secret
      - global.minio.endpoint=http://10.104.49.50:9000 # minio地址
      - global.namespace=tamp-system # Use default values
      - tamp-portal.image.registry=172.22.96.19 # harbor address
      - tamp-portal.image.tag=v5.6.0 # tamp-portal image version
      - tamp-portal.ingress.className=portal-ingress # Use default values
      - tamp-portal.ingress.hostName=portal.192.168.96.40.nip.io 
      - gateway-management.image.registry=172.22.96.19 # harbor address
      - gateway-management.image.tag=v5.6.0 # gateway-management image version
      - gateway-management.ingress.className=portal-ingress # Use default values
      - gateway-management.ingress.hostName=portal.192.168.96.40.nip.io 

```
Create componentplan
```
kubectl apply -f componentplan.yaml
```

# Uninstall steps
The name of the installed chart package can be viewed in the specified namespace
```bash
kubectl get componentplan -n kubebb-system
```
Select the specified componentplan for uninstallation
```bash
kubectl delete componentplan name -n kubebb-system
```

# Gateway usage
## 1.1 AI service definition 

View configmap in tamp-system
```bash
kubectl get configmap ai-supplyer  -n tamp-system
```
If not, create a self replacement AI service address such as ali, openai, and local to facilitate the identification of the service as an AI service
```bash
kubectl create -f - <<EOF
apiVersion: v1
data:
  ali: alidemo:8080 # ali service
  local: aiservice:8080  # local services
  openai: open.bigmodel.cn:443  # Other open services
kind: ConfigMap
metadata:
  name: ai-supplyer # Use default values
  namespace: tamp-system # Use default values
EOF
```
## 1.2 Create gateway environment
View namespace  kong-system
```bash
kubectl get namespace kong-system
```
If not, create a namespace
```bash
kubectl --as=admin --as-group=iam.tenxcloud.com create -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
     capsule.clastix.io/tenant: system-tenant
  name: kong-system
EOF
```
### 1.3 Create kong
1.3.1 View Kong's CRD
```bash
kubectl get crd|grep kongs.charts.konghq.com
```
If there is no need to create this CRD for Kong
```bash
kubectl apply -f deploy/crd/kong-crd.yaml
```
- Create a gateway environment through the help method and modify the content of values kong yaml in the help, as follows:
```bash
  image:
    registry: 192.168.90.228 # image warehouse address
  name: kong # name
  clusterId: host-cluster # cluster id
  tenantId: system-tenant # Tenant where the gateway environment is located
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key:   # The key for binding the label of nodes in the gateway environment
                operator: In
                values:
                  - k8s-node-3  # The value of the label of the gateway environment bound node
```
#### Creating a KONG environment using the helm method
Helm package location：deploy/helm中
```bash
helm install tamp-kong . -n kong-system -f values-kong.yaml
```
#### The API usage instructions can refer to the introduction in examples.
