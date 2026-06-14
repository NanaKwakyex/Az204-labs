# 01-app-service\n\nComing soon.

# Lab 01 — Azure App Service

## What this lab covers

| AZ-204 exam objective                    | This lab                             |
| ---------------------------------------- | ------------------------------------ |
| Create an Azure App Service Web App      | Bicep provisions Plan + Web App      |
| Configure and monitor App Service apps   | Diagnostic settings → Log Analytics  |
| Deploy apps to App Service               | GitHub Actions zip deploy            |
| Configure SSL, custom domains, settings  | HTTPS-only, TLS 1.2, app settings    |
| Implement autoscaling                    | See stretch goals below              |
| Use deployment slots                     | Staging slot + swap to production    |
| Use Key Vault references in app settings | `@Microsoft.KeyVault(...)` pattern   |
| Configure managed identity               | System-assigned identity → KV policy |

---

## Architecture

```
GitHub Actions
     │
     ├─ Bicep deploy ──► Resource Group
     │                        │
     │                   ┌────┴──────────────────────┐
     │                   │  App Service Plan (B1)     │
     │                   │  Linux                     │
     │                   └────┬──────────────────────┘
     │                        │
     │              ┌─────────┴──────────┐
     │              │   Web App          │
     │              │   production slot  │◄── swap ──┐
     │              │   (Python 3.11)    │           │
     │              └────────────────────┘           │
     │                        │                      │
     │              ┌─────────┴──────────┐           │
     │              │   staging slot     │◄── zip deploy
     │              └────────────────────┘
     │
     │                   Key Vault
     │                   └─ my-secret ◄── @Microsoft.KeyVault ref
     │                        ▲
     │                   Managed Identity (system-assigned)
     │
     └─────────────► Log Analytics Workspace
                         └─ App Service diagnostic logs
```

---

## Folder structure

```
01-app-service/
├── README.md
├── infra/
│   └── main.bicep          ← all Azure resources
└── src/
    ├── app.py               ← Flask application
    ├── requirements.txt
    └── startup.txt          ← gunicorn startup command
```

---

## Prerequisites

- Azure subscription with Contributor access
- Service principal `az204-labs-sp` credentials stored as `AZURE_CREDENTIALS` in GitHub secrets
- `LAB_NAME_SUFFIX` secret set in GitHub — pick any 5-6 alphanumeric chars (e.g. `xk7f2`)
  - This prevents global naming conflicts for Key Vault and Web App

---

## How to run

### 1. Create the branch

```bash
git checkout -b lab/01-App-Service-deploy
```

### 2. Copy files into your repo layout

Place files exactly as shown in the folder structure above.

### 3. Add the `LAB_NAME_SUFFIX` GitHub secret

```
GitHub repo → Settings → Secrets and variables → Actions → New repository secret
Name:  LAB_NAME_SUFFIX
Value: <your 5-6 char suffix, e.g. xk7f2>
```

### 4. Push and watch the workflow

```bash
git add .
git commit -m "lab(01): scaffold App Service lab"
git push origin lab/01-App-Service-deploy
```

The workflow will:

1. Lint and what-if the Bicep template
2. Provision all Azure resources
3. Deploy the app to the **staging** slot
4. Run a health check against staging
5. Wait for manual approval (configure the `production` environment in GitHub)
6. Swap staging → production

### 5. Set up the GitHub Environment gate (one-time)

```
GitHub repo → Settings → Environments → New environment
Name: production
☑ Required reviewers → add yourself
```

---

## Key exam concepts exercised

### Deployment slots

The workflow deploys to `staging` first, smoke-tests, then swaps.

```bash
# Manual swap via CLI (same as what the workflow does)
az webapp deployment slot swap \
  --resource-group rg-az204-lab01 \
  --name <webAppName> \
  --slot staging \
  --target-slot production
```

**Exam gotcha:** Deployment slots require **Basic tier or higher**. Free (F1) does not support slots.

### Key Vault references

App settings can reference Key Vault secrets without the app ever calling the Key Vault API directly:

```
@Microsoft.KeyVault(SecretUri=https://<vault>.vault.azure.net/secrets/<name>/)
```

The App Service platform resolves the reference at startup using the web app's managed identity. The app just reads `os.getenv("MY_SECRET")`.

**Requirements:**

1. Web app has a system-assigned managed identity
2. Key Vault access policy grants the identity `get` on secrets
3. App setting value uses the `@Microsoft.KeyVault(...)` syntax

### Managed identity

No credentials are stored anywhere. The web app authenticates to Key Vault via its system-assigned identity — the platform handles token acquisition automatically.

### Diagnostic settings

All HTTP logs, console output, and platform events are streamed to Log Analytics:

```bash
# Query app logs in Log Analytics
az monitor log-analytics query \
  --workspace <lawId> \
  --analytics-query "AppServiceHTTPLogs | where ScStatus >= 400 | take 20"
```

---

## Stretch goals (after core lab)

These are not in the workflow but good exam practice:

```bash
# 1. Enable autoscale on the plan
az monitor autoscale create \
  --resource-group rg-az204-lab01 \
  --resource <planName> \
  --resource-type Microsoft.Web/serverfarms \
  --name autoscale-lab01 \
  --min-count 1 --max-count 3 --count 1

# 2. Add a scale-out rule (CPU > 70% for 5 min)
az monitor autoscale rule create \
  --resource-group rg-az204-lab01 \
  --autoscale-name autoscale-lab01 \
  --scale out 1 \
  --condition "CpuPercentage > 70 avg 5m"

# 3. Slot-specific app setting (not swapped with slot)
az webapp config appsettings set \
  --resource-group rg-az204-lab01 \
  --name <webAppName> \
  --slot staging \
  --slot-settings ENVIRONMENT=staging
```

---

## Cleanup

```bash
az group delete --name rg-az204-lab01 --yes --no-wait
```

This removes all resources and stops all billing for the lab.

---

## PR checklist

When merging to `main`, confirm:

- [ ] Bicep what-if ran cleanly with no unexpected changes
- [ ] App deployed successfully to staging slot
- [ ] `/health` returns HTTP 200 on staging
- [ ] Slot swap completed and production `/health` returns HTTP 200
- [ ] `/secret-peek` returns a masked value (proves Key Vault reference resolved)
- [ ] Log Analytics shows AppServiceHTTPLogs within ~5 minutes
- [ ] Resource group deleted after lab (or tagged for cleanup)
