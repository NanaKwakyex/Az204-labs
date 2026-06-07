# Az204-labs

AZ-204 exam prep — hands-on Azure labs with GitHub Actions CI/CD

# AZ-204 Labs

Hands-on Azure labs built while preparing for the AZ-204 Developer Associate exam.
Each lab deploys a real working application to Azure via GitHub Actions.

## Lab index

| #   | Lab                                     | Exam domain                                   | Status      |
| --- | --------------------------------------- | --------------------------------------------- | ----------- |
| 01  | [App Service](./01-app-service)         | Implement Azure App Service web apps (15–20%) | In progress |
| 02  | [Azure Functions](./02-azure-functions) | Implement Azure Functions (15–20%)            | To do       |
| 03  | [Blob Storage](./03-blob-storage)       | Develop solutions using Blob storage (15–20%) | To do       |
| 04  | [Cosmos DB](./04-cosmos-db)             | Develop solutions using Cosmos DB (15–20%)    | To do       |
| 05  | [Containers](./05-containers)           | Implement containerized solutions (10–15%)    | To do       |
| 06  | [API Management](./06-api-management)   | Implement API Management (10–15%)             | To do       |
| 07  | [Event Grid](./07-event-grid)           | Develop event-based solutions (10–15%)        | To do       |
| 08  | [Service Bus](./08-service-bus)         | Develop message-based solutions (10–15%)      | To do       |
| 09  | [Key Vault](./09-key-vault)             | Implement Azure security (15–20%)             | To do       |
| 10  | [Monitoring](./10-monitoring)           | Instrument solutions — App Insights (10–15%)  | To do       |

## How this repo is structured

Each lab folder contains:

- `README.md` — what the lab does and why it matters for the exam
- `infra/` — Bicep templates to provision Azure resources
- `src/` — application code
- `.github/workflows/` — GitHub Actions deployment pipeline

## Prerequisites

- Azure subscription
- Azure CLI installed
- VS Code + Azure Tools extension pack
