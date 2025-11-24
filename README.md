# Azure IoT Operations - WebAssembly Data Flow Graphs

This repository demonstrates how to build and deploy custom WebAssembly (WASM) modules for data processing with Azure IoT Operations data flow graphs. WASM modules enable high-performance, sandboxed data transformations at the edge.

## Overview

Azure IoT Operations data flow graphs support WebAssembly modules for custom data processing at the edge. You can deploy custom business logic and data transformations as part of your data flow pipelines. This project includes:

- **Custom WASM modules** written in Rust
- **Deployment configurations** for Azure IoT Operations
- **Sample data flow graphs** demonstrating temperature filtering and processing

## Prerequisites

- **Azure IoT Operations** instance deployed on an Arc-enabled Kubernetes cluster (can be deployed using `make deploy_aio`)
- **Azure Container Registry (ACR)** for storing WASM modules (can be deployed using `make deploy_acr`)
- [ORAS CLI](https://oras.land/docs/installation) for pushing WASM modules to registry
- Rust toolchain for building WASM modules
- kubectl access to your Kubernetes cluster

## Repository Structure

```text
.
├── rust/
│   └── filter/          # Custom WASM filter module
│       ├── Cargo.toml   # Rust dependencies
│       └── src/
│           └── lib.rs   # Filter implementation
├── deploy/
│   ├── acr-push.sh                  # Script to push WASM to ACR
│   ├── create-role-assignment.sh    # Script to configure ACR permissions
│   ├── deploy-aio.sh                # Azure IoT Operations deployment
│   ├── dataflow-graph.yaml          # Data flow graph configuration
│   └── graph-simple.yaml            # Graph definition
├── makefile             # Build and deployment automation
└── README.md

```

## Getting Started

This project includes a `makefile` to simplify building and deploying WASM modules. The makefile automates the compilation of Rust code to WebAssembly and pushes the artifacts to Azure Container Registry.

**Quick Start with Makefile:**

```bash
# Run all steps
make

# Run a single step, e.g. push the module to ACR
make push_wasm_module_to_acr

# Clean build artifacts
make clean
```

The makefile handles all the complexity of targeting the correct WebAssembly architecture (`wasm32-wasip2`) and using [ORAS](https://oras.land/) to push OCI artifacts to your registry.

### 1. Build WASM Modules

Build the custom filter module:

```bash
make build_wasm_module
```

This compiles the Rust code to WebAssembly Component Model format in the `rust/filter/target/wasm32-wasip2/release/` directory.

### 2. Push to Azure Container Registry

Set your ACR name and push the WASM module:

```bash
export ACR_NAME=<YOUR_ACR_NAME>
make push_wasm_module_to_acr
```

This uses the ORAS CLI to push the compiled WASM module to your container registry.

### 3. Configure Registry Endpoint

Create a registry endpoint in Azure IoT Operations to access your ACR (can also be deployed using `make deploy_registry_endpoint`):

```bash
az iot ops registry create \
  -n registry-endpoint-acr \
  --host <YOUR_ACR_NAME>.azurecr.io \
  -i <AIO_INSTANCE_NAME> \
  -g <RESOURCE_GROUP> \
  --auth-type SystemAssignedManagedIdentity \
  --aud https://management.azure.com/
```

### 4. Configure ACR Permissions

Grant the Azure IoT Operations managed identity access to pull from ACR:

```bash
# Get IoT Operations extension name
EXTENSION_NAME=$(az k8s-extension list \
  --resource-group <RESOURCE_GROUP> \
  --cluster-name <CLUSTER_NAME> \
  --cluster-type connectedClusters \
  --query "[?extensionType=='microsoft.iotoperations'].name" \
  --output tsv)

# Get managed identity
EXTENSION_OBJ_ID=$(az k8s-extension show \
  --name $EXTENSION_NAME \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type connectedClusters \
  --query "identity.principalId" \
  --output tsv)

# Assign AcrPull role
az role assignment create \
  --role "AcrPull" \
  --assignee $EXTENSION_OBJ_ID \
  --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.ContainerRegistry/registries/<ACR_NAME>"
```

### 5. Deploy Data Flow Graph

Apply the data flow graph configuration:

```bash
kubectl apply -f deploy/dataflow-graph.yaml
```

## How Data Flow Graphs Work

The WASM data flow implementation follows this workflow:

1. **Develop WASM modules**: Write custom processing logic in Rust and compile to WebAssembly Component Model
2. **Develop graph definition**: Define data flow through modules using YAML configuration
3. **Store artifacts in registry**: Push compiled WASM modules to container registry using ORAS
4. **Configure registry endpoints**: Set up authentication for Azure IoT Operations to access the registry
5. **Create data flow**: Define data sources, artifact references, and destinations
6. **Deploy and execute**: Azure IoT Operations pulls WASM modules and runs them based on graph definition

## Example: Filter Module

The included filter module demonstrates a basic data processing pattern:

```yaml
# Graph definition (graph-simple.yaml)
nodes:
  - nodeType: Source
    name: sensor-source
    sourceSettings:
      endpointRef: default
      dataSources:
        - sensor/temperature/raw

  - nodeType: Graph
    name: filter-processor
    graphSettings:
      registryEndpointRef: my-acr-endpoint
      artifact: filter:1.0.0

  - nodeType: Destination
    name: sensor-destination
    destinationSettings:
      endpointRef: default
      dataDestination: sensor/temperature/filtered
```

## Testing

Deploy the MQTT client for testing:

```bash
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/explore-iot-operations/main/samples/quickstarts/mqtt-client.yaml
```

### Publish Test Messages

```bash
kubectl exec --stdin --tty mqtt-client -n azure-iot-operations -- sh -c '
# Create and run temperature.sh from within the MQTT client pod
while true; do
  # Generate a random temperature value between 0 and 6000 Celsius
  random_value=$(shuf -i 0-6000 -n 1)
  payload="{\"temperature\":{\"value\":$random_value,\"unit\":\"C\"}}"

  echo "Publishing temperature: $payload"

  # Publish to the input topic
  mosquitto_pub -h aio-broker -p 18883 \
    -m "$payload" \
    -t "raw" \
    -d \
    --cafile /var/run/certs/ca.crt \
    -D PUBLISH user-property __ts $(date +%s)000:0:df \
    -D CONNECT authentication-method 'K8S-SAT' \
    -D CONNECT authentication-data $(cat /var/run/secrets/tokens/broker-sat)

  sleep 1
done'```

### Subscribe to Processed Messages

```bash
kubectl exec --stdin --tty mqtt-client -n azure-iot-operations -- sh -c '
mosquitto_sub -h aio-broker -p 18883 \
  -t "processed" \
  --cafile /var/run/certs/ca.crt \
  -D CONNECT authentication-method "K8S-SAT" \
  -D CONNECT authentication-data "$(cat /var/run/secrets/tokens/broker-sat)"'
```

## Development

### Building Custom WASM Modules

1. Create a new Rust project with WebAssembly target
2. Implement your processing logic using the data flow interfaces
3. Compile to `wasm32-wasip2` target
4. Push to container registry with versioning

See the [official documentation](https://learn.microsoft.com/azure/iot-operations/connect-to-cloud/howto-develop-wasm-modules) for detailed guidance on developing WASM modules.

### Graph Definition Configuration

Graph definitions specify how data flows through WASM modules. Key elements:

- **Operations**: Processing steps (map, filter, join, branch)
- **Connections**: Data flow between operations
- **Module references**: WASM modules to execute
- **Configuration**: Runtime parameters for modules

See the [graph definition documentation](https://learn.microsoft.com/azure/iot-operations/connect-to-cloud/howto-configure-wasm-graph-definitions) for complete configuration options.

## Makefile Targets

- `make all` - Run complete deployment pipeline (cluster, AIO, ACR, build, and deploy)
- `make create_k3d_cluster` - Create local k3d Kubernetes cluster for development
- `make deploy_aio` - Deploy Azure IoT Operations to Arc-enabled cluster
- `make deploy_acr` - Create Azure Container Registry
- `make create_role_assignment` - Configure ACR permissions for AIO managed identity
- `make deploy_registry_endpoint` - Create registry endpoint in Azure IoT Operations
- `make build_wasm_module` - Build WASM modules from Rust source
- `make push_wasm_module_to_acr` - Push modules to Azure Container Registry
- `make deploy_dataflow_graph` - Deploy data flow graph configuration
- `make clean` - Delete k3d cluster and clean build artifacts

## Important Notes

- Data flow graphs currently support **MQTT, Kafka, and OpenTelemetry endpoints only**
- WASM modules run in a sandboxed environment with high performance and security
- Supports Rust and Python for module development
- Use semantic versioning for WASM artifacts (e.g., `filter:1.0.0`)

## Resources

- [Use WebAssembly with data flow graphs](https://learn.microsoft.com/azure/iot-operations/connect-to-cloud/howto-dataflow-graph-wasm)
- [Develop WebAssembly modules](https://learn.microsoft.com/azure/iot-operations/connect-to-cloud/howto-develop-wasm-modules)
- [Configure graph definitions](https://learn.microsoft.com/azure/iot-operations/connect-to-cloud/howto-configure-wasm-graph-definitions)
- [Azure IoT Operations documentation](https://learn.microsoft.com/azure/iot-operations)

## License

See [LICENSE](LICENSE) file for details.
