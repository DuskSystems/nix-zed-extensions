//! We only care about fields relevant to building.
//! Any other fields will be left as is.

use std::{collections::BTreeMap, path::PathBuf};

use serde::{Deserialize, Serialize};
use toml::Value;

#[derive(Debug, Serialize, Deserialize)]
pub struct ExtensionManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub schema_version: i32,

    #[serde(default)]
    pub lib: LibManifestEntry,

    #[serde(default)]
    pub themes: Vec<PathBuf>,
    #[serde(default)]
    pub icon_themes: Vec<PathBuf>,
    #[serde(default)]
    pub languages: Vec<PathBuf>,
    #[serde(default)]
    pub grammars: BTreeMap<String, GrammarManifestEntry>,
    #[serde(default)]
    pub snippets: Option<PathBuf>,

    #[serde(flatten)]
    _other: BTreeMap<String, Value>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct LibManifestEntry {
    pub version: Option<String>,

    #[serde(flatten)]
    _other: BTreeMap<String, Value>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct GrammarManifestEntry {
    pub repository: String,
    #[serde(alias = "commit")]
    pub rev: String,
    #[serde(default)]
    pub path: Option<String>,

    #[serde(flatten)]
    _other: BTreeMap<String, Value>,
}
