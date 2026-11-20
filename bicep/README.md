<!--
@license
Copyright (c) rljson

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# bicep

One folder per component, one parameter file each:

```text
bicep/<component>/main.bicep
bicep/<component>/<component>.bicepparam
```

Every component deploys into the resource group `rg-cars` and serves all
stages. Every `main.bicep` declares `param techResponsibility string` and
sets the tags `application: cars`, `environment: shared` and
`techresponsibility` on each resource; `deploy.js` passes the signed-in
user. Each `.bicepparam` assigns `techResponsibility` the placeholder `''`,
which `deploy.js` overrides. A component that declares
`param clusterAdminGroupIds array` gets the object IDs of the groups
`cars-admins` and `cars-operators`.

`node test.js` builds every file; it is the test of this repo and runs
before each commit. `node deploy.js <component|all>` deploys with a
what-if first; `all` deploys the components in the order of this table.

| Component            | Resources                                                                  | Settings                                                                                                                                                                                                                                                         |
| -------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `log-analytics`      | Log Analytics workspace `log-cars`                                         | 30 days retention, daily cap 1 GB                                                                                                                                                                                                                                |
| `container-registry` | Container registry `crcars`                                                | Basic, admin user off; images built with `az acr build`                                                                                                                                                                                                          |
| `network`            | VNet `vnet-cars`, subnets `snet-cars-<pool>`, NSGs `nsg-cars-<pool>`, subnet `snet-cars-endpoints` with `nsg-cars-endpoints`, private DNS zones of SQL and blob | 10.10.0.0/16; a /24 per node pool: system `.0`, origin `.1`, custom `.2`; the private endpoints in `.3`, the zones linked to the VNet; web on 80 and 443 from the internet allowed, the VNet open inside, since the nodes of all pools must reach each other                                                                    |
| `aks`                | Cluster `aks-cars`, identity `id-aks-cars`, node group `rg-cars-aks`       | Free tier; pools `system` with two `Standard_D2s_v6` nodes, since the managed Istio of the add-on alone requests 1 vCPU, and `origin` and `custom` with one each, in the subnet of their name, `origin` and `custom` tainted `side=<pool>:NoSchedule` and labelled `side=<pool>`; Entra sign-in with Azure RBAC, no local accounts; OIDC issuer and workload identity; Azure CNI overlay with Cilium, pods 10.244.0.0/16, services 10.0.0.0/16; AcrPull on `crcars` for the nodes; application routing add-on with the managed Gateway API and Istio, no NGINX; needs `container-registry` and `network` |
| `aks-schedule`       | Logic App `logic-aks-cars-stop`                                            | Stops `aks-cars` every day at 20:00 W. Europe Standard Time; its managed identity holds the Azure Kubernetes Service Contributor Role on this cluster only; start the cluster with `az aks start`; needs `aks` |
| `data-identities`    | Identities `id-cars-<side>-master-<stage>`, `id-cars-sql-admin`            | Each master identity federated with `system:serviceaccount:cars-<side>-<stage>:master`, `id-cars-sql-admin` with `system:serviceaccount:cars-data:sql-users`, through the OIDC issuer of `aks-cars`; the rights come from `sql` and `storage`; needs `aks` |
| `sql`                | Servers `sql-cars-<side>`, databases `sqldb-cars-<side>-<stage>`, private endpoints `pe-sql-cars-<side>` | Entra sign-in only with `id-cars-sql-admin` as admin, no public network access, TLS 1.2; Basic with 2 GB per database; endpoints in `snet-cars-endpoints`, names in `privatelink.database.windows.net`; the users of the masters are created in the cluster; needs `network` and `data-identities` |
| `storage`            | Accounts `stcars<side>`, containers `dev`, `test`, `prod`, private endpoints `pe-st-cars-<side>` | Standard LRS, no shared keys, no anonymous blobs, no public network access, TLS 1.2; *Storage Blob Data Contributor* for each master identity on its own container only; endpoints in `snet-cars-endpoints`, names in `privatelink.blob.core.windows.net`; needs `network` and `data-identities` |
| `github`             | Identities `id-cars-github-build`, `id-cars-github-scan`, Key Vault `kv-cars-github` | Federated credentials for GitHub Actions: `build` on `main` of `buildRepos` with AcrPush on `crcars` and Key Vault Secrets User, `scan` on pull requests of `scanRepos` with AcrPull; the admin groups are Key Vault Secrets Officers; needs `container-registry` |
