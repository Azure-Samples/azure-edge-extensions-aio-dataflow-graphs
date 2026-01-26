K3DCLUSTERNAME := devcluster
PORTFORWARDING := -p '8883:8883@loadbalancer' -p '1883:1883@loadbalancer'
ARCCLUSTERNAME := arc-wasm-dataflows
STORAGEACCOUNTNAME := sawasmdataflows
SCHEMAREGISTRYNAME := sr-wasm-dataflows
SCHEMANAME := temperature-schema
DEVICEREGISTRYNAME := adr-wasm-dataflows
ACRNAME := acr-wasm-dataflows
RESOURCEGROUP := rg-wasm-dataflows
AIOINSTANCE := $(ARCCLUSTERNAME)
LOCATION := westeurope

all: create_k3d_cluster deploy_aio deploy_acr create_role_assignment deploy_registry_endpoint build_wasm_module push_wasm_module_to_acr create_schema deploy_dataflow_graph

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
	cargo build --release --target wasm32-wasip2 --manifest-path ./rust/filter/Cargo.toml --config ./rust/.cargo/config.toml
	cargo build --release --target wasm32-wasip2 --manifest-path ./rust/schema-validation/Cargo.toml --config ./rust/.cargo/config.toml
	@echo "Building WASM Module for Map..."
	cargo build --release --target wasm32-wasip2 --manifest-path ./rust/map/Cargo.toml --config ./rust/.cargo/config.toml
	cargo build --release --target wasm32-wasip2 --manifest-path ./rust/custom/Cargo.toml --config ./rust/.cargo/config.toml
	wasm-tools metadata add ./rust/custom/target/wasm32-wasip2/release/custom_provider.wasm --name "custom-provider" -o ./rust/custom/target/wasm32-wasip2/release/custom-provider.wasm
	wasm-tools component wit ./rust/map/target/wasm32-wasip2/release/map_custom.wasm
	wasm-tools component wit ./rust/custom/target/wasm32-wasip2/release/custom-provider.wasm
	wasm-tools compose ./rust/map/target/wasm32-wasip2/release/map_custom.wasm -d ./rust/custom/target/wasm32-wasip2/release/custom-provider.wasm -o ./rust/map/target/wasm32-wasip2/release/composed_map_custom.wasm

push_wasm_module_to_acr:
	@echo "Pushing WASM Module to ACR..."
	az acr login --name $(ACRNAME)
	oras push $(ACRNAME).azurecr.io:/graph-simple-filter:1.0.0 --config /dev/null:application/vnd.microsoft.aio.graph.v1+yaml ./deploy/graph-simple-filter.yaml:application/yaml --disable-path-validation
	oras push $(ACRNAME).azurecr.io:/graph-simple-schema-validation:1.0.0 --config /dev/null:application/vnd.microsoft.aio.graph.v1+yaml ./deploy/graph-simple-schema-validation.yaml:application/yaml --disable-path-validation
	oras push $(ACRNAME).azurecr.io:/graph-simple-map-custom:1.0.0 --config /dev/null:application/vnd.microsoft.aio.graph.v1+yaml ./deploy/graph-simple-map-custom.yaml:application/yaml --disable-path-validation
	oras push $(ACRNAME).azurecr.io/filter:1.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm ./rust/filter/target/wasm32-wasip2/release/filter.wasm:application/wasm
	oras push $(ACRNAME).azurecr.io/schema-validation:1.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm ./rust/schema-validation/target/wasm32-wasip2/release/schema_validation.wasm:application/wasm
	oras push $(ACRNAME).azurecr.io/map-custom:1.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm ./rust/map/target/wasm32-wasip2/release/composed_map_custom.wasm:application/wasm

create_schema:
	@echo "Creating JSON Schema in Schema Registry..."
	az iot ops schema create -n $(SCHEMANAME) -g $(RESOURCEGROUP) --registry $(SCHEMAREGISTRYNAME) --format json --type message --version-content ./deploy/temperature-schema.json

deploy_dataflow_graph:
	@echo "Deploying Dataflow Graph..."
	cp ./deploy/dataflow-graph-template.yaml ./deploy/dataflow-graph-temp.yaml
	# on a mac (sed -i '' "s?__{schema_ref}__?$(SCHEMAREGISTRYNAME)/$(SCHEMANAME)?g" ./deploy/dataflow-graph-temp.yaml)
	sed -i "s?__{schema_ref}__?$(SCHEMAREGISTRYNAME)/$(SCHEMANAME)?g" ./deploy/dataflow-graph-temp.yaml
	kubectl apply -f ./deploy/dataflow-graph-temp.yaml
	rm -f ./deploy/dataflow-graph-temp.yaml

clean:
	@echo "Cleaning up..."
	k3d cluster delete $(K3DCLUSTERNAME)