K3DCLUSTERNAME := devcluster
PORTFORWARDING := -p '8883:8883@loadbalancer' -p '1883:1883@loadbalancer'
ARCCLUSTERNAME := arck-wasm-valmet-007# arc-wasm-dataflows
STORAGEACCOUNTNAME := sawasmdataflows
SCHEMAREGISTRYNAME := sr-wasm-dataflows
DEVICEREGISTRYNAME := adr-wasm-dataflows
ACRNAME := acrwasmvalmet007# acr-wasm-dataflows
RESOURCEGROUP := rg-wasm-valmet-007# rg-wasm-dataflows
AIOINSTANCE := iotops-arck-wasm-valmet-007
LOCATION := westeurope

all: create_k3d_cluster deploy_aio deploy_acr create_role_assignment deploy_registry_endpoint build_wasm_module push_wasm_module_to_acr deploy_dataflow_graph

create_k3d_cluster:
	@echo "Creating k3d cluster..."
	k3d cluster create $(K3DCLUSTERNAME) $(PORTFORWARDING) --servers 1

deploy_aio:
	@echo "Deploying AIO..."
	bash ./deploy/deploy-aio.sh $(ARCCLUSTERNAME) $(STORAGEACCOUNTNAME) $(SCHEMAREGISTRYNAME) $(RESOURCEGROUP) $(LOCATION) $(DEVICEREGISTRYNAME) $(ACRNAME)

deploy_acr:
	@echo "Deploying ACR..."
	az acr create --name $(ACRNAME) --resource-group $(RESOURCEGROUP) --sku Standard

create_role_assignment:
	@echo "Creating Role Assignment..."
	bash ./deploy/create-role-assignment.sh $(ARCCLUSTERNAME) $(RESOURCEGROUP) $(ACRNAME)

deploy_registry_endpoint:
	@echo "Deploying Registry Endpoint..."
	az iot ops registry create -n registry-endpoint-acr --host $(ACRNAME).azurecr.io -i $(AIOINSTANCE) -g $(RESOURCEGROUP) --auth-type SystemAssignedManagedIdentity --aud https://management.azure.com/

build_wasm_module:
	@echo "Building WASM Module..."
	cargo build --release --target wasm32-wasip2 --manifest-path ./rust/filter/Cargo.toml --config ./rust/filter/.cargo/config.toml

push_wasm_module_to_acr:
	@echo "Pushing WASM Module to ACR..."
	az acr login --name $(ACRNAME)
	oras push $(ACRNAME).azurecr.io:/graph-simple:1.0.0 --config /dev/null:application/vnd.microsoft.aio.graph.v1+yaml ./deploy/graph-simple.yaml:application/yaml --disable-path-validation
	oras push $(ACRNAME).azurecr.io/filter:1.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm ./rust/filter/target/wasm32-wasip2/release/filter.wasm:application/wasm

deploy_dataflow_graph:
	@echo "Deploying Dataflow Graph..."
	kubectl apply -f ./deploy/dataflow-graph.yaml

clean:
	@echo "Cleaning up..."
	k3d cluster delete $(K3DCLUSTERNAME)