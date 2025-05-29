use std::{
    collections::{BTreeMap},
    path::PathBuf,
};

use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct ExtensionManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub schema_version: i32,

    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub repository: Option<String>,
    #[serde(default)]
    pub authors: Vec<String>,
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
    pub language_servers: BTreeMap<String, LanguageServerManifestEntry>,
    #[serde(default)]
    pub context_servers: BTreeMap<String, ContextServerManifestEntry>,
    #[serde(default)]
    pub slash_commands: BTreeMap<String, SlashCommandManifestEntry>,
    #[serde(default)]
    pub indexed_docs_providers: BTreeMap<String, IndexedDocsProviderEntry>,
    #[serde(default)]
    pub snippets: Option<PathBuf>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct LibManifestEntry {
    pub kind: Option<ExtensionLibraryKind>,
    pub version: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum ExtensionLibraryKind {
    Rust,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct GrammarManifestEntry {
    pub repository: String,
    #[serde(alias = "commit")]
    pub rev: String,
    #[serde(default)]
    pub path: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LanguageServerManifestEntry {
    #[serde(default)]
    language: Option<String>,
    #[serde(default)]
    languages: Vec<String>,
    #[serde(default)]
    pub language_ids: BTreeMap<String, String>,
    #[serde(default)]
    pub code_action_kinds: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ContextServerManifestEntry {}

#[derive(Debug, Serialize, Deserialize)]
pub struct SlashCommandManifestEntry {
    pub description: String,
    pub requires_argument: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct IndexedDocsProviderEntry {}
