use serde::Deserialize;

#[derive(Deserialize, Debug, Clone)]
pub struct RegistryEntry {
    pub version: String,
    pub submodule: String,
    pub path: Option<String>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RegistryExtension {
    pub name: String,
    pub version: String,
    pub repository: String,
    pub path: Option<String>,
    pub rev: String,
}
