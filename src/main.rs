use std::collections::{BTreeMap, HashSet};
use std::env::temp_dir;
use std::num::NonZero;
use std::path::Path;
use std::process::Command;
use std::sync::Arc;

use futures::StreamExt;
use futures::stream::FuturesUnordered;
use registry::RegistryExtension;
use tokio::fs;
use tokio::sync::Semaphore;

use crate::manifest::ExtensionManifest;
use crate::output::NixExtensions;
use crate::registry::RegistryEntry;
use crate::sync::process_extension;
use crate::wasm::extract_zed_api_version;

pub mod manifest;
pub mod output;
pub mod registry;
pub mod sync;
pub mod wasm;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .compact()
        .without_time()
        .with_target(false)
        .init();

    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("sync") => {
            let output_path = Path::new("extensions.json");
            let mut output: NixExtensions = if output_path.exists() {
                tracing::info!("Loading existing extensions");
                serde_json::from_str(&fs::read_to_string(output_path).await?)?
            } else {
                NixExtensions::default()
            };

            tracing::info!("Cloning extensions registry");

            let tmp_registry = temp_dir().join("registry");
            if tmp_registry.exists() {
                fs::remove_dir_all(&tmp_registry).await?;
            }

            let clone = Command::new("git")
                .args([
                    "clone",
                    "--depth",
                    "1",
                    "https://github.com/zed-industries/extensions",
                    &tmp_registry.to_string_lossy(),
                ])
                .status()?;

            if !clone.success() {
                anyhow::bail!("Failed to clone extensions repository");
            }

            // Lookup registry extensions
            let registry = tmp_registry.join("extensions.toml");
            let registry = fs::read_to_string(registry).await?;
            let registry: BTreeMap<String, RegistryEntry> = toml::from_str(&registry)?;

            // Parse submodule revisions
            let submodules = Command::new("git")
                .current_dir(&tmp_registry)
                .args(["submodule", "status"])
                .output()?;

            if !submodules.status.success() {
                anyhow::bail!("Failed to get submodule status");
            }

            let submodules = String::from_utf8(submodules.stdout)?.trim().to_owned();

            let mut revisions: BTreeMap<String, String> = BTreeMap::new();
            for line in submodules.lines() {
                let parts: Vec<&str> = line.splitn(2, ' ').collect();

                let revision = parts[0].trim_start_matches('-').to_owned();
                let path = parts[1].to_owned();

                revisions.insert(path, revision);
            }

            // Parse submodule repositories
            let gitmodules = Command::new("git")
                .current_dir(&tmp_registry)
                .args(["config", "--file", ".gitmodules", "--list"])
                .output()?;

            if !gitmodules.status.success() {
                anyhow::bail!("Failed to get submodule repositories");
            }

            let gitmodules = String::from_utf8(gitmodules.stdout)?.trim().to_owned();

            let mut repositories: BTreeMap<String, String> = BTreeMap::new();
            for line in gitmodules.lines() {
                let parts: Vec<&str> = line.splitn(2, '=').collect();

                let path = parts[0]
                    .trim_start_matches("submodule.")
                    .trim_end_matches(".url")
                    .to_owned();

                let repository = parts[1].trim_end_matches(".git").to_owned();
                repositories.insert(path, repository);
            }

            // Merge details
            let mut extensions: Vec<RegistryExtension> = vec![];
            for (name, entry) in &registry {
                let Some(repository) = repositories.get(&entry.submodule) else {
                    tracing::warn!(
                        submodule = ?entry.submodule,
                        "Missing submodule repository"
                    );

                    continue;
                };

                let Some(revision) = revisions.get(&entry.submodule) else {
                    tracing::warn!(
                        submodule = ?entry.submodule,
                        "Missing submodule revision"
                    );

                    continue;
                };

                extensions.push(RegistryExtension {
                    name: name.clone(),
                    version: entry.version.clone(),
                    repository: repository.to_string(),
                    path: entry.path.clone(),
                    rev: revision.to_string(),
                });
            }

            let extension_names: HashSet<String> = registry
                .iter()
                .map(|extension| extension.0.clone())
                .collect();

            // Handle removed extensions/grammars
            let removed_extensions: Vec<String> = output
                .extensions
                .iter()
                .filter(|existing| !extension_names.contains(&existing.name))
                .map(|ext| ext.name.clone())
                .collect();

            for name in &removed_extensions {
                tracing::info!(
                    name = name,
                    "Removing extension that is no longer maintained"
                );

                if let Some(extension) = output.extensions.iter().find(|e| &e.name == name) {
                    output
                        .grammars
                        .retain(|grammar| !extension.grammars.contains(&grammar.id));
                }
            }

            output
                .extensions
                .retain(|existing| !removed_extensions.contains(&existing.name));

            // Filter remaining extensions/grammars
            let extensions = extensions
                .into_iter()
                .filter(|extension| {
                    // Skip extension that haven't changed.
                    if let Some(existing) = output
                        .extensions
                        .iter()
                        .find(|existing| existing.name == extension.name)
                    {
                        if existing.version >= extension.version {
                            tracing::debug!(name = extension.name, "Skipping unchanged extension");
                            return false;
                        }

                        tracing::info!(name = extension.name, "New extension version");

                        // Remove outdated extensions and grammars from output.
                        let grammars = existing.grammars.clone();
                        output
                            .extensions
                            .retain(|existing| existing.name != extension.name);

                        output
                            .grammars
                            .retain(|grammar| !grammars.contains(&grammar.id));
                    }

                    true
                })
                .collect::<Vec<_>>();

            let limit = std::thread::available_parallelism()
                .map(NonZero::get)
                .unwrap_or(1)
                * 2;

            let semaphore = Arc::new(Semaphore::new(limit));

            let mut futures = FuturesUnordered::new();
            for extension in extensions {
                let semaphore = Arc::clone(&semaphore);
                let future = async move {
                    let _acquire = semaphore.acquire().await?;
                    process_extension(extension).await
                };

                futures.push(future);
            }

            while let Some(result) = futures.next().await {
                match result {
                    Ok(Some((extension, grammars))) => {
                        output.extensions.push(extension);
                        output.grammars.extend(grammars);
                    }
                    Ok(_) => (),
                    Err(err) => tracing::error!(
                        err = ?err,
                        "Error processing extension"
                    ),
                }
            }

            tracing::info!("Writing output");

            output.extensions.sort_by(|a, b| a.name.cmp(&b.name));
            output.grammars.sort_by(|a, b| a.id.cmp(&b.id));

            let output = serde_json::to_string_pretty(&output)?;
            fs::write(output_path, output).await?;
            fs::remove_dir_all(tmp_registry).await?;
        }

        Some("populate") => {
            let path = Path::new(".");

            let manifest_path = path.join("extension.toml");
            if !manifest_path.exists() {
                anyhow::bail!("Missing extension.toml");
            }

            let manifest = fs::read_to_string(&manifest_path).await?;
            let mut manifest: ExtensionManifest = toml::from_str(&manifest)?;

            let wasm = &path.join("extension.wasm");
            if wasm.exists() {
                let version = extract_zed_api_version(wasm)?;
                manifest.lib.version = Some(version);
            }

            let languages = &path.join("languages");
            if languages.exists() {
                let mut language_entries = fs::read_dir(languages).await?;
                while let Some(language) = language_entries.next_entry().await? {
                    let language_path = language.path();
                    let config = language_path.join("config.toml");
                    if fs::metadata(&config).await.is_ok() {
                        let relative_language_dir = language_path.strip_prefix(path)?.to_path_buf();
                        if !manifest.languages.contains(&relative_language_dir) {
                            manifest.languages.push(relative_language_dir);
                        }
                    }
                }
            }

            let themes = &path.join("themes");
            if themes.exists() {
                let mut theme_entries = fs::read_dir(themes).await?;
                while let Some(theme) = theme_entries.next_entry().await? {
                    let theme_path = theme.path();
                    if theme_path.extension() == Some("json".as_ref()) {
                        let relative_theme_path = theme_path.strip_prefix(path)?.to_path_buf();
                        if !manifest.themes.contains(&relative_theme_path) {
                            manifest.themes.push(relative_theme_path);
                        }
                    }
                }
            }

            let icon_themes = &path.join("icon_themes");
            if icon_themes.exists() {
                let mut icon_theme_entries = fs::read_dir(icon_themes).await?;
                while let Some(icon_theme) = icon_theme_entries.next_entry().await? {
                    let icon_theme_path = icon_theme.path();
                    if icon_theme_path.extension() == Some("json".as_ref()) {
                        let relative_icon_theme_path =
                            icon_theme_path.strip_prefix(path)?.to_path_buf();
                        if !manifest.icon_themes.contains(&relative_icon_theme_path) {
                            manifest.icon_themes.push(relative_icon_theme_path);
                        }
                    }
                }
            }

            let snippets = &path.join("snippets.json");
            if fs::metadata(snippets).await.is_ok() {
                manifest.snippets = Some(snippets.to_owned());
            }

            tracing::info!("Writing output");
            let manifest = toml::to_string_pretty(&manifest)?;
            fs::write(manifest_path, manifest).await?;
        }

        Some("check") => {
            let nix_name = &args[2];
            tracing::info!(
                name = ?nix_name,
                "Nix Name"
            );

            let nix_grammars: HashSet<String> = args[3..].iter().cloned().collect();
            tracing::info!(
                grammars = ?nix_grammars,
                "Nix Grammars"
            );

            let manifest_path = Path::new("extension.toml");
            if !manifest_path.exists() {
                anyhow::bail!("Missing extension.toml");
            }

            let manifest = fs::read_to_string(&manifest_path).await?;
            let manifest: ExtensionManifest = toml::from_str(&manifest)?;

            let toml_id = &manifest.id;
            tracing::info!(
                id = ?toml_id,
                "Extension ID"
            );

            let toml_grammars: HashSet<String> = manifest.grammars.keys().cloned().collect();
            tracing::info!(
                grammars = ?toml_grammars,
                "Extension Grammars"
            );

            if toml_id != nix_name {
                anyhow::bail!(
                    "Extension ID '{toml_id}' does not match Nix package name '{nix_name}'"
                );
            }

            for toml_grammar in &toml_grammars {
                if !nix_grammars.contains(toml_grammar) {
                    anyhow::bail!("Missing Nix grammar package: '{toml_grammar}'");
                }
            }

            for nix_grammar in &nix_grammars {
                if !toml_grammars.contains(nix_grammar) {
                    anyhow::bail!("Unexpected Nix grammar package: '{nix_grammar}'");
                }
            }

            tracing::info!("Nix extension is valid!");
        }

        _ => {
            anyhow::bail!("Unknown command");
        }
    }

    Ok(())
}
