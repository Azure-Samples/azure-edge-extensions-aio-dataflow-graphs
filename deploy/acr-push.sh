#! /bin/bash

export ACR_NAME=$1

# Log in to your ACR
az acr login --name $ACR_NAME

# Push modules to your registry
oras pull tkmodules.azurecr.io/graph-simple:3.0.0
oras pull tkmodules.azurecr.io/graph-complex:3.0.0
oras pull tkmodules.azurecr.io/graph-schema:3.0.0
oras pull tkmodules.azurecr.io/temperature:3.0.0 
oras pull tkmodules.azurecr.io/window:3.0.0 
oras pull tkmodules.azurecr.io/snapshot:3.0.0
oras pull tkmodules.azurecr.io/format:3.0.0
oras pull tkmodules.azurecr.io/schema-registry:3.0.0
oras pull tkmodules.azurecr.io/schema:3.0.0
oras pull tkmodules.azurecr.io/humidity:3.0.0 
oras pull tkmodules.azurecr.io/collection:3.0.0
oras pull tkmodules.azurecr.io/enrichment:3.0.0

oras push $ACR_NAME.azurecr.io:/graph-simple:3.0.0 --config /dev/null:application/vnd.microsoft.aio.graph.v1+yaml graph-simple.yaml:application/yaml --disable-path-validation
oras push $ACR_NAME.azurecr.io:/graph-complex:3.0.0 --config /dev/null:application/vnd.microsoft.aio.graph.v1+yaml graph-complex.yaml:application/yaml --disable-path-validation
oras push $ACR_NAME.azurecr.io:/graph-schema:3.0.0 --config /dev/null:application/vnd.microsoft.aio.graph.v1+yaml graph-schema.yaml:application/yaml --disable-path-validation
oras push $ACR_NAME.azurecr.io/temperature:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm temperature-3.0.0.wasm:application/wasm
oras push $ACR_NAME.azurecr.io/humidity:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm humidity-3.0.0.wasm:application/wasm
oras push $ACR_NAME.azurecr.io/collection:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm collection-3.0.0.wasm:application/wasm
oras push $ACR_NAME.azurecr.io/enrichment:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm enrichment-3.0.0.wasm:application/wasm
oras push $ACR_NAME.azurecr.io/format:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm format-3.0.0.wasm:application/wasm
oras push $ACR_NAME.azurecr.io/schema-registry:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm schema-registry-3.0.0.wasm:application/wasm
oras push $ACR_NAME.azurecr.io/schema:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm schema-3.0.0.wasm:application/wasm
oras push $ACR_NAME.azurecr.io/snapshot:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm snapshot-3.0.0.wasm:application/wasm 
oras push $ACR_NAME.azurecr.io/window:3.0.0 --artifact-type application/vnd.module.wasm.content.layer.v1+wasm window-3.0.0.wasm:application/wasm
