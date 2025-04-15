use serde::Deserialize;

#[derive(Deserialize, Debug, Clone)]
pub struct RegistryEntry {
    pub version: String,
    pub submodule: String,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RegistryExtension {
    pub id: String,
    pub version: String,
    pub repository: String,
    pub rev: String,
}
