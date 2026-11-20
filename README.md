<!--
@license
Copyright (c) rljson

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# cars-infra

English | [Deutsch](README.de.md)

The Azure resources of the cars application, an example app built on
Rljson: Node.js scripts to bootstrap, deploy and test, and one Bicep
component per resource, among them the Kubernetes cluster.

## Motivation

- Every Azure resource of cars is described in git, so it can be rebuilt
  from this repo alone
- Each deploy shows a what-if first and applies only after a yes
- What runs on these resources lives in
  [cars-deployment](https://github.com/cars-world/cars-deployment), so a
  change to an image never touches the Azure resources

## Layout

| Path                     | Content                                                                  |
| ------------------------ | ------------------------------------------------------------------------ |
| `bootstrap/bootstrap.js` | Run once: registers the resource providers, creates the group `rg-cars`  |
| `deploy.js`              | Deploys one component or all of them into `rg-cars`                      |
| `changed.js`             | Lists the components a change touches, for the workflows                 |
| `.github/workflows`      | `plan`: what-if on pull requests; `deploy`: deploy after the approval    |
| `test.js`                | Runs the unit tests of `lib` and builds every Bicep and parameter file   |
| `lib`                    | Settings and checks shared by the scripts, with their tests              |
| `bicep`                  | One folder per component: `main.bicep` and `<component>.bicepparam`      |

All resources live in one resource group `rg-cars` in Germany West
Central and serve the stages `dev`, `test` and `prod` together: one
Kubernetes cluster `aks-cars`, one registry, one network and one Log
Analytics workspace, and a Logic App that stops the cluster every
evening. What separates the stages and the
sides inside the cluster, namespaces, quotas and network policies, is not
part of this repo.

```mermaid
flowchart LR
  subgraph rg["rg-cars"]
    log["log-cars"]
    cr["crcars"]
    subgraph vnet["vnet-cars"]
      sys["snet-cars-system"]
      ori["snet-cars-origin"]
      cus["snet-cars-custom"]
    end
    aks["aks-cars<br/>pools system, origin, custom"]
  end
  aks -- "nodes in" --> vnet
  aks -- "pulls from" --> cr
```

## Usage

Install [Node.js](https://nodejs.org) 22 or later, the
[Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and
its Bicep CLI once:

```bash
az bicep install
```

Sign in with your own Entra account first; the operator needs the group
`cars-admins` or `cars-operators`.

```bash
az login
az account set --subscription cars
```

Prepare the subscription once:

```bash
node bootstrap/bootstrap.js
```

Deploy all components in order; each shows its what-if first and nothing
changes before your yes:

```bash
node deploy.js all
```

Deploy one component, or only show the changes:

```bash
node deploy.js network
node deploy.js network --what-if
```

`--yes` applies after the what-if without asking, for runs without a
terminal. The scripts check the active subscription first. Every resource
gets the tag `techresponsibility` with the signed-in user. The component
`aks` gives the groups `cars-admins` and `cars-operators` admin rights in
the cluster; `deploy.js` looks up their object IDs by name.

There is no DNS zone: the apps use the free Azure names under
`germanywestcentral.cloudapp.azure.com`, carried by the public IPs of
their Gateways, which are not part of this repo.

Sign in to the cluster with your Entra account:

```bash
az aks get-credentials --resource-group rg-cars --name aks-cars
kubelogin convert-kubeconfig -l azurecli
```

The component `aks-schedule` stops the cluster every day at 20:00
Berlin time. Start it by hand before you work with it; it takes a few
minutes:

```bash
az aks start --resource-group rg-cars --name aks-cars
```

The component `github` lets GitHub Actions sign in to Azure through
OpenID Connect, without a stored secret: `id-cars-github-build` for the
workflows on `main` of the repos in `buildRepos`, which push images to
`crcars` and read the Key Vault `kv-cars-github`, and
`id-cars-github-scan` for the pull requests and the workflows on `main`
of the repos in `scanRepos`, which only pull. GitHub signs the subjects
of `cars-world` with immutable IDs, e.g.
`repo:cars-world@358216462/cars-origin-master@1453837020:ref:refs/heads/main`,
so `github.bicepparam` names each repo with its ID; a repo created again
under the same name cannot sign in. The groups `cars-admins` and
`cars-operators` may write secrets into the Key Vault, e.g. the private
key of a GitHub App:

```bash
az keyvault secret set --vault-name kv-cars-github \
  --name <secret> --file <path-to-key>
```

## Deploy from git

A pull request into `main` that changes `bicep/<component>/` gets the
check `what-if` from the workflow `plan`: it signs in as
`id-cars-github-infra-plan`, which may read and simulate but change
nothing, and posts the what-if of each changed component as a comment.
`main` takes changes through pull requests only, each reviewed by the
code owner. After the merge the workflow `deploy` waits in the GitHub
environment `azure` until a required reviewer approves it, then signs in
as `id-cars-github-infra` and runs `node deploy.js <component> --yes` for
the changed components. **Actions → Deploy → Run workflow** deploys one
component again.

`id-cars-github-infra` is Contributor on `rg-cars` and may assign only the
roles the components use. `github` and `github-infra` grant the rights of
the workflows themselves and are deployed by hand only. The object IDs of
the groups `cars-admins` and `cars-operators` lie in the parameter files,
so no workflow reads Entra ID; on a laptop `deploy.js` asks Entra ID only
when a file leaves them empty.

Set up once, by hand:

```bash
node deploy.js github-infra
gh api -X POST repos/cars-world/cars-infra/rulesets --input .github/rulesets/main.json
```

Then the repository variables `AZURE_CLIENT_ID_INFRA_PLAN` and
`AZURE_CLIENT_ID_INFRA` (the client IDs of the two identities),
`AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID`, and the environment `azure`
with its required reviewer.

## Test

Before each commit:

```bash
node test.js
```

## Limitations

- `bootstrap.js`, `github` and `github-infra` run by hand from a machine
- No databases, storage or workload identities of the apps yet
- The cluster stops every evening at 20:00 and runs only after a manual
  `az aks start`, so the apps of every stage, prod included, are offline
  until then. Running day and night, four nodes, two of them in the pool
  `system`, cost about 120 to 270 USD a month at list prices; stopped, only the disks, the public IP
  and the load balancer cost, about 20 USD a month. The control plane is
  in the Free tier, without an uptime SLA

## Status

| Component            | Resources                                                         | Deployed |
| -------------------- | ----------------------------------------------------------------- | -------- |
| `log-analytics`      | `log-cars`                                                        | yes      |
| `container-registry` | `crcars`                                                          | yes      |
| `network`            | `vnet-cars`, `snet-cars-<pool>`, `nsg-cars-<pool>`; `snet-cars-endpoints`, `nsg-cars-endpoints` and the private DNS zones of SQL and blob | yes; the endpoints with the next merge |
| `aks`                | `aks-cars`, `id-aks-cars`, node resource group `rg-cars-aks`      | yes      |
| `aks-schedule`       | `logic-aks-cars-stop`                                             | yes      |
| `data-identities`    | `id-cars-<side>-master-<stage>`, `id-cars-sql-admin`              | with the next merge |
| `sql`                | `sql-cars-<side>`, `sqldb-cars-<side>-<stage>`, `pe-sql-cars-<side>` | with the next merge |
| `storage`            | `stcars<side>`, containers `<stage>`, `pe-st-cars-<side>`        | with the next merge |
| `github`             | `id-cars-github-build`, `id-cars-github-scan`, `kv-cars-github`   | yes      |
| `github-infra`       | `id-cars-github-infra-plan`, `id-cars-github-infra`, a what-if role | yes    |
