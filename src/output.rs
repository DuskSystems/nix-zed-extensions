use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct NixExtensions {
    pub extensions: Vec<Extension>,
    pub grammars: Vec<Grammar>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Extension {
    pub id: String,
    pub version: String,
    pub src: Source,
    #[serde(rename = "extensionRoot", skip_serializing_if = "Option::is_none")]
    pub extension_root: Option<String>,
    pub grammars: Vec<String>,
    #[serde(flatten)]
    pub kind: ExtensionKind,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum ExtensionKind {
    Plain,

    Rust {
        #[serde(rename = "cargoHash")]
        cargo_hash: String,
        #[serde(rename = "cargoLock", skip_serializing_if = "Option::is_none")]
        cargo_lock: Option<CargoLock>,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CargoLock {
    #[serde(rename = "lockFile")]
    pub lock_file: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Source {
    url: String,
    rev: String,
    date: String,
    path: String,
    sha256: String,
    hash: String,
    #[serde(rename = "fetchLFS")]
    fetch_lfs: bool,
    #[serde(rename = "fetchSubmodules")]
    fetch_submodules: bool,
    #[serde(rename = "deepClone")]
    deep_clone: bool,
    #[serde(rename = "leaveDotGit")]
    leave_dot_git: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Grammar {
    pub id: String,
    pub name: String,
    pub version: String,
    pub src: Source,
}
