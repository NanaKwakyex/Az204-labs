// ============================================================
// Lab 01 — App Service
// AZ-204: Azure Developer Associate
//
// Provisions:
//   - Log Analytics Workspace
//   - App Service Plan (B1 Linux)
//   - Web App + staging slot (system-assigned managed identity)
//   - Key Vault + access policies for both identities
//   - Key Vault secret (seed value)
//   - App settings (patched after KV exists to avoid circular ref)
//   - Diagnostic Settings → Log Analytics
//
// Circular reference fix:
//   webApp is declared first with a placeholder MY_SECRET value.
//   keyVault is declared second, referencing webApp.identity.principalId.
//   Microsoft.Web/sites/config 'appsettings' is declared last and
//   replaces the placeholder with the real @Microsoft.KeyVault(...) reference.
// ============================================================

@description('Environment suffix')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Short unique suffix to avoid global name collisions (5-6 alphanumeric chars)')
@maxLength(6)
param nameSuffix string

@description('App Service Plan SKU — B1 minimum for deployment slots')
param appServicePlanSku string = 'B1'

@description('Python runtime version')
param pythonVersion string = '3.11'

// ── Naming ─────────────────────────────────────────────────
// All names are derived from parameters — no hardcoded values.
// nameSuffix comes from your LAB_NAME_SUFFIX GitHub Actions secret.
// Example with nameSuffix=xk7f2, environment=dev:
//   planName     → az204-plan-xk7f2-dev
//   webAppName   → az204-app-xk7f2-dev
//   keyVaultName → az204-kv-xk7f2-dev   (Key Vault max 24 chars)
//   lawName      → az204-law-xk7f2-dev
var prefix = 'az204'
var planName = '${prefix}-plan-${nameSuffix}-${environment}'
var webAppName = '${prefix}-app-${nameSuffix}-${environment}'
var keyVaultName = '${prefix}-kv-${nameSuffix}-${environment}'
var lawName = '${prefix}-law-${nameSuffix}-${environment}'

// ── 1. Log Analytics Workspace ─────────────────────────────
// Declared first — no dependencies.
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ── 2. App Service Plan ────────────────────────────────────
// B1 is the cheapest tier that supports deployment slots.
// Free (F1) does NOT support slots — common exam gotcha.
// reserved: true is required for Linux plans.
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: planName
  location: location
  sku: {
    name: appServicePlanSku
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ── 3. Web App ─────────────────────────────────────────────
// Declared BEFORE Key Vault so that webApp.identity.principalId
// is available for the Key Vault access policy below.
// MY_SECRET is a placeholder here — patched in step 7 (webAppSettings).
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|${pythonVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'ENVIRONMENT'
          value: environment
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          // Placeholder — replaced by webAppSettings resource below
          // once the Key Vault URI is known.
          name: 'MY_SECRET'
          value: 'pending-keyvault-reference'
        }
      ]
    }
  }
}

// ── 4. Staging Deployment Slot ─────────────────────────────
// Also declared before Key Vault for the same reason —
// stagingSlot.identity.principalId is needed in the KV access policy.
resource stagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = {
  name: 'staging'
  parent: webApp
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|${pythonVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'ENVIRONMENT'
          value: 'staging'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'MY_SECRET'
          value: 'pending-keyvault-reference'
        }
      ]
    }
  }
}

// ── 5. Key Vault ───────────────────────────────────────────
// Declared AFTER webApp and stagingSlot so their principalIds are resolved.
// Both identities get get+list on secrets so the KV reference app setting works.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: webApp.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: stagingSlot.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
  }
}

// ── 6. Seed Secret ─────────────────────────────────────────
// Adds a placeholder secret so the KV reference resolves on first deploy.
// Replace the actual value via CLI after deployment:
//   az keyvault secret set --vault-name <name> --name my-secret --value <real-value>
resource mySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'my-secret'
  parent: keyVault
  properties: {
    value: 'change-me-after-deploy'
  }
}

// ── 7. Web App Settings (with real KV reference) ───────────
// Microsoft.Web/sites/config 'appsettings' REPLACES all app settings —
// it is not additive. Every setting you need must be listed here.
// This resource depends on keyVault and mySecret implicitly via the
// @Microsoft.KeyVault(...) URI, and Bicep resolves the order correctly.
resource webAppSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  name: 'appsettings'
  parent: webApp
  dependsOn: [
    mySecret
  ]
  properties: {
    ENVIRONMENT: environment
    SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
    MY_SECRET: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/my-secret/)'
  }
}

// ── 8. Staging Slot Settings (with real KV reference) ──────
resource stagingSlotSettings 'Microsoft.Web/sites/slots/config@2023-01-01' = {
  name: 'appsettings'
  parent: stagingSlot
  dependsOn: [
    mySecret
  ]
  properties: {
    ENVIRONMENT: 'staging'
    SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
    MY_SECRET: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/my-secret/)'
  }
}

// ── 9. Diagnostic Settings ─────────────────────────────────
// Streams App Service logs and metrics to Log Analytics.
// Query logs with: AppServiceHTTPLogs | where ScStatus >= 400
resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: webApp
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'AppServiceHTTPLogs', enabled: true }
      { category: 'AppServiceConsoleLogs', enabled: true }
      { category: 'AppServiceAppLogs', enabled: true }
      { category: 'AppServiceAuditLogs', enabled: true }
      { category: 'AppServicePlatformLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// ── Outputs ────────────────────────────────────────────────
// These are captured by the GitHub Actions workflow and passed
// between jobs (infra → deploy-staging → swap).
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output stagingSlotUrl string = 'https://${stagingSlot.properties.defaultHostName}'
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output lawId string = law.id
output principalId string = webApp.identity.principalId
