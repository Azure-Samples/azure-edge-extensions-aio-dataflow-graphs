// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

#![allow(clippy::missing_safety_doc)]

wit_bindgen::generate!({
    path: "wit/custom.wit",
    world: "custom-provider",
});

use exports::map::custom::custom::{DataModel, Error, Guest, ModuleConfiguration};
use wasm_graph_sdk::logger::{self, Level};

struct CustomProvider;

impl Guest for CustomProvider {
    fn init(configuration: ModuleConfiguration) -> bool {
        logger::log(
            Level::Info,
            "module-custom/provider",
            "Initialization function invoked",
        );
        // Log or process configuration properties
        for (key, value) in &configuration.properties {
            // Process each configuration property
            let _ = (key, value);
        }
        true
    }

    fn process(message: DataModel) -> Result<DataModel, Error> {
        logger::log(
            Level::Info,
            "module-custom/provider",
            "Process function invoked",
        );
        // Default implementation: pass through the data unchanged
        // Customize this logic as needed
        Ok(DataModel {
            payload: message.payload,
        })
    }
}

export!(CustomProvider);
