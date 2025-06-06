# SENSE Helm Charts

A simple and central place for distribution of helm charts for the SENSE Orchestrator platform.

The SENSE-O deployment is container based and both Docker Stack or Kubernetes can be used. This repo is focused on artifacts for the Kubernetes deployment. SENSE-O consists of two major components: the Orchestrator server and the Keycloak SSO server that can be separately deployed. The below diagram shows the structure of the overall deployment with a breakdown into the orchestrator and keycloak charts. Detailed intructions are provided for both in their respective folders in this repo.

![SENSE-Dev-Env-planning-review-v2-sense-helm](https://github.com/user-attachments/assets/4bc74735-8b59-482f-9d26-51f071ebc367)

As a practical example of how to use these charts, let's assume the following:

> This tutorial was written on 2025-04-05, using chart versions OC:1.11.0 and KC:0.6.4 .

- We are deploying to a cluster with a storage provisioner and ingress controller set up, as well as a cert-manager `ClusterIssuer` named `le-sense-cluster`.
- We are deploying both the Orchestrator and Keycloak to the same cluster, within the `sense` namespace.
- We want the Orchestrator to be accessible at `orch.sense-o.es.net`, and Keycloak to be accessible at `kc.sense-o.es.net`.

1. The first step to deploying the helm charts is to add this repository to our local helm cache:

```
helm repo add sense-helm https://stackv.github.io/sense-helm/
helm repo update
```

2. Next, we need to create some baseline secrets for the charts to use. Namely, we're going to create three of them:

   - For Keycloak we need to set the initial admin password: `kubectl -n sense create secret generic sense-kc-cred --from-literal=admin-password='{REPLACE_ME}'`.
   - For the orchestrator install we need to establish a set of passwords for various components (DB access, Client TLS, SMTP): `kubectl -n sense create secret generic sense-orch-cred --from-literal=tls-password='{REPLACE_ME}' --from-literal=mysql-password='{REPlACE_ME}' --from-literal=mail-password='nomail'`
   - For the orchestrator to connect to provider API or standalone RMs, we'll also need a client keystore file: `kubectl -n sense create secret generic sense-client-keystore --from-file={REPLACE_ME}/client.keystore`. This keystore file can be provided by us, or you can assemble your own JKS client certificate store.

3. With those secrets in place, we can now configure our local value files. To do this we'll create two files, `keycloak.values.yaml` and `orchestrator.values.yaml`. For more information about the options available, please see the individual chart directories. Make sure to adjust the following if you change the names of any secrets above.

_keycloak.values.yaml_

```yaml
global:
  secret:
    name: sense-kc-cred
namespaceOverride: sense
ingress:
  annotations:
    cert-manager.io/cluster-issuer: le-sense-cluster
  authHostname: kc-auth.sense-o.es.net
  hostname: kc.sense-o.es.net
```

_orchestrator.values.yaml_

```yaml
global:
  namespace: sense
  domain: orch.sense-o.es.net
  keycloak: kc-auth.sense-o.es.net
  credSecret: sense-orch-cred
ingress:
  annotations:
    cert-manager.io/cluster-issuer: le-sense-cluster
resources:
  requests:
    cpu: 500m
    memory: 2Gi
tls:
  keystoreSecret: sense-client-keystore
```

4. With all that in place, all that is left is to install the two stacks via helm:

```
helm -n sense install local-sense-keycloak sense-helm/sense-keycloak --version 0.6.3 -f keycloak.values.yaml
```

```
helm -n sense install local-sense-orchestrator sense-helm/sense-orchestrator --version 1.9.3 -f orchestrator.values.yaml
```
* Note that sense-keycloak and sense-orchestrator can be deployed separately, meaning that one can only deploy the sense-orchestrator and point it to a previously deployed or shared sense-keycloak server.


5. Assuming everything was provisioned correctly, we should be able to access our services after a couple minutes of initialization time.

- The Keycloak administration console should be available at `https://kc.sense-o.es.net/auth/admin/`, and we can login with the username `admin` and password equal to whatever we set the `admin-password` key to in Step 2. From here go to the Users tab and add a new user using the button at the top right. After this new user is created, we'll click into it, head to the Role Mappings tab, and add the `A_Admin` role to create our new admin user. Once we hit Save we'll have made our first real user.
- Once the Orchestrator is online it should now be available at `https://orch.sense-o.es.net/StackV-web/portal`. Accessing it should prompt you with a login, where we can use our new user credentials.
