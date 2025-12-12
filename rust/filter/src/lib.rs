#![allow(clippy::missing_safety_doc)]

#[derive(Debug, PartialEq, serde::Deserialize, serde::Serialize)]
pub enum Measurement {
    #[serde(rename = "temperature")]
    Temperature(MeasurementTemperature),

    #[serde(rename = "humidity")]
    Humidity(MeasurementHumidity),

    #[serde(rename = "object")]
    Object(MeasurementObject),

    #[serde(rename = "sensor_data")]
    SensorData(MeasurementSensorData),
}

#[derive(Debug, PartialEq, serde::Deserialize, serde::Serialize)]
pub struct MeasurementTemperature {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub value: Option<f64>,
    #[serde(default)]
    pub count: u64,
    #[serde(default)]
    pub max: f64,
    #[serde(default)]
    pub min: f64,
    #[serde(default)]
    pub average: f64,
    #[serde(default)]
    pub last: f64,
    pub unit: MeasurementTemperatureUnit,
    #[serde(default)]
    pub overtemp: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, serde::Deserialize, serde::Serialize)]
pub enum MeasurementTemperatureUnit {
    #[serde(rename = "C")]
    Celsius,

    #[serde(rename = "F")]
    Fahrenheit,
}

#[derive(Debug, PartialEq, serde::Deserialize, serde::Serialize)]
pub struct MeasurementHumidity {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub value: Option<f64>,
    #[serde(default)]
    pub count: u64,
    #[serde(default)]
    pub max: f64,
    #[serde(default)]
    pub min: f64,
    #[serde(default)]
    pub average: f64,
    #[serde(default)]
    pub last: f64,
}

#[derive(Debug, PartialEq, serde::Deserialize, serde::Serialize)]
pub struct MeasurementObject {
    pub result: String,
}

#[derive(Debug, PartialEq, serde::Deserialize, serde::Serialize)]
pub struct MeasurementSensorData {
    #[serde(default)]
    pub temperature: Vec<MeasurementTemperature>,

    #[serde(default)]
    pub humidity: Vec<MeasurementHumidity>,

    #[serde(default)]
    pub object: Vec<MeasurementObject>,
}

impl Default for MeasurementSensorData {
    fn default() -> Self {
        Self::new()
    }
}

impl MeasurementSensorData {
    pub fn new() -> Self {
        Self {
            temperature: Vec::new(),
            humidity: Vec::new(),
            object: Vec::new(),
        }
    }

    pub fn temperature(&mut self) -> &mut [MeasurementTemperature] {
        &mut self.temperature
    }

    pub fn humidity(&mut self) -> &mut [MeasurementHumidity] {
        &mut self.humidity
    }

    pub fn object(&mut self) -> &mut [MeasurementObject] {
        &mut self.object
    }
}

mod filter_temperature {
    use core::panic;
    use std::sync::OnceLock;

    use crate::{Measurement, MeasurementTemperature, MeasurementTemperatureUnit};

    use wasm_graph_sdk::logger::{self, Level};
    use wasm_graph_sdk::macros::filter_operator;
    use wasm_graph_sdk::metrics::{self, CounterValue, Label};

    static LOWER_BOUND: OnceLock<f64> = OnceLock::new();
    static UPPER_BOUND: OnceLock<f64> = OnceLock::new();

    /// Note!: The initialization parameters LOWER_BOUND and UPPER_BOUND must be set via
    /// configuration properties. If these values are not configured, the function
    /// filter_temperature will panic when attempting to access them.
    ///
    /// Users can define these parameters either by using default values or by specifying
    /// them during application setup
    fn filter_temperature_init(configuration: ModuleConfiguration) -> bool {
        logger::log(
            Level::Info,
            "module-temperature/filter",
            &format!("Initialization function invoked"),
        );

        if let Some(value_string) = configuration
            .properties
            .iter()
            .find(|(key, _value)| key == "temperature_lower_bound") // or whatever it is
            .map(|(_key, value)| value.clone())
        {
            match value_string.parse::<f64>() {
                Ok(value) => {
                    let _ = LOWER_BOUND.set(value);
                    logger::log(
                        Level::Info,
                        "module-temperature/filter",
                        &format!("Lower bound set to {value}"),
                    );
                }
                Err(_) => {
                    logger::log(
                        Level::Error,
                        "module-temperature/filter",
                        &format!("Failed to parse lower bound value: {value_string}"),
                    );
                }
            }
        }

        if let Some(value_string) = configuration
            .properties
            .iter()
            .find(|(key, _value)| key == "temperature_upper_bound") // or whatever it is
            .map(|(_key, value)| value.clone())
        {
            match value_string.parse::<f64>() {
                Ok(value) => {
                    let _ = UPPER_BOUND.set(value);
                    logger::log(
                        Level::Info,
                        "module-temperature/filter",
                        &format!("Upper bound set to {value}"),
                    );
                }
                Err(_) => {
                    logger::log(
                        Level::Error,
                        "module-temperature/filter",
                        &format!("Failed to parse upper bound value: {value_string}"),
                    );
                }
            }
        }

        true
    }

    #[filter_operator(init = "filter_temperature_init")]
    fn filter_temperature(input: DataModel) -> Result<bool, Error> {
        logger::log(
            Level::Info,
            "module-temperature/filter",
            &format!(
                "Filter function invoked - lower_bound: {:?}, upper_bound: {:?}",
                LOWER_BOUND.get(),
                UPPER_BOUND.get()
            ),
        );

        let labels = vec![Label {
            key: "module".to_owned(),
            value: "module-temperature/filter".to_owned(),
        }];
        let _ = metrics::add_to_counter("requests", CounterValue::U64(1), Some(&labels));

        // Extract payload from input to process
        let payload = match input {
            DataModel::Message(Message {
                payload: BufferOrBytes::Buffer(buffer),
                ..
            }) => {
                logger::log(Level::Info, "module-temperature/filter", "Received Buffer type");
                buffer.read()
            },
            DataModel::Message(Message {
                payload: BufferOrBytes::Bytes(bytes),
                ..
            }) => {
                logger::log(Level::Info, "module-temperature/filter", "Received Bytes type");
                bytes
            },
            ref other => {
                logger::log(
                    Level::Error,
                    "module-temperature/filter",
                    &format!("Unexpected input type: {:?}", other),
                );
                panic!("Unexpected input type");
            }
        };
        logger::log(Level::Info, "module-temperature/filter", "payload defined");

        let measurement: Measurement = serde_json::from_slice(&payload).unwrap();

        logger::log(
            Level::Info,
            "module-temperature/filter",
            &format!("incoming measurement {measurement:?}"),
        );

        let lower_bound = LOWER_BOUND.get().expect("Lower bound not initialized");
        let upper_bound = UPPER_BOUND.get().expect("Upper bound not initialized");

        // Malfunctioning probe sometimes reports higher temperature than melting point of tungsten.
        // Ignore these values.
        Ok(matches!(
            measurement,
            Measurement::Temperature(MeasurementTemperature {
                count: _,
                value,
                max: _,
                min: _,
                average: _,
                last: _,
                unit: MeasurementTemperatureUnit::Celsius,
                overtemp: _,
            }) if value.unwrap() < *upper_bound && value.unwrap() > *lower_bound,
        ))
    }
}
