# Foundry Connection

Create a connection in Microsoft Foundry that points to your APIM.

Pick one model discovery mode - a connection uses either dynamic discovery or a
static model list, never both.

| Folder | Mode | How models are found | Required APIM operations |
|--------|------|----------------------|--------------------------|
| [dynamic-discovery/](dynamic-discovery/) | Dynamic | Foundry calls `ListDeployments` / `GetDeployment` on APIM at runtime | ChatCompletions + both discovery operations |
| [static-models/](static-models/) | Static | Model list is stored in the connection metadata | ChatCompletions only |

**Which to use:** a static list is simpler, costs no extra APIM calls, and is what
Microsoft recommends for this sample's scenario. The setup guide is explicit that
its dynamic discovery instructions assume an Azure OpenAI or Foundry resource behind
APIM: *"For any other backend services, ensure you properly setup and test it out,
otherwise use static discovery for simplicity."* Compass is exactly such a backend.

Dynamic discovery is still worth using when the model list changes often and you want
APIM to stay the single source of truth - just be aware the discovery endpoints have to
be implemented by hand (this sample mocks them in policy).

Either way, `deploymentInPath` must match how the gateway routes chat completions,
and the connection is referenced from an agent as `<connection-name>/<deployment-name>`
(for example `compass-connection/gpt-5`).

## Connection Properties

| Property | Value | Description |
|----------|-------|-------------|
| `category` | `ApiManagement` | Tells Foundry this is an APIM proxy |
| `authType` | `ApiKey` | Uses API key authentication |
| `target` | APIM URL | Base URL for all calls |
| `isSharedToAll` | `true` | Shares the connection with every project user. The official template defaults to `false` - set it there if the APIM key should not be visible to all members |

## Metadata Reference

Metadata drives how Foundry calls the gateway. Complex values (objects and arrays)
must be stored as serialized JSON strings, which both templates handle.

| Key | Used by | Description |
|-----|---------|-------------|
| `deploymentInPath` | both | `"true"` for `/deployments/{name}/chat/completions`, `"false"` when the model goes in the body as `model` |
| `inferenceAPIVersion` | both | `api-version` for chat completions. Omitted entirely when empty, which makes Foundry use its own default |
| `deploymentAPIVersion` | dynamic | `api-version` appended to discovery calls only. Omitted when empty, so no query param is added |
| `modelDiscovery` | dynamic | `listModelsEndpoint`, `getModelEndpoint`, `deploymentProvider` |
| `models` | static | The model list, in `ModelInfo` shape |
| `authConfig` | neither (not exposed) | Overrides the header name and value format used to send the APIM key, e.g. `x-api-key` or `Bearer {api_key}` |
| `customHeaders` | neither (not exposed) | Extra headers added to every inference call |

See [APIM Connection Objects](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/APIM-Connection-Objects.md)
for the full field reference, and the README in each folder for parameters and the deploy command.
