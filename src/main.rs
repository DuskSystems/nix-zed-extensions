use std::path::Path;
use std::sync::Arc;

use clap::{Parser, Subcommand};
use futures::stream::FuturesUnordered;
use futures::StreamExt;
use tokio::fs;
use tokio::sync::Semaphore;
use tracing_subscriber::EnvFilter;

use crate::api::ApiResponse;
use crate::config::Config;
use crate::manifest::ExtensionManifest;
use crate::output::NixExtensions;
use crate::sync::process_extension;
use crate::wasm::extract_zed_api_version;

pub mod api;
pub mod config;
pub mod manifest;
pub mod output;
pub mod sync;
pub mod wasm;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Sync extensions from the Zed API.
    Sync,

    /// Populate extension manifest.
    Populate,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .compact()
        .without_time()
        .with_target(false)
        .with_env_filter(
            EnvFilter::builder()
                .with_default_directive("nix_zed_extensions=debug".parse().unwrap())
                .from_env()
                .unwrap(),
        )
        .init();

    let cli = Cli::parse();

    let config = Path::new("config.toml");
    let config: Config = if config.exists() {
        toml::from_str(&fs::read_to_string(config).await?)?
    } else {
        Config::default()
    };

    match &cli.command {
        Commands::Sync => {
            let output_path = Path::new("extensions.json");
            let mut output: NixExtensions = if output_path.exists() {
                tracing::info!("Loading existing extensions");
                serde_json::from_str(&fs::read_to_string(output_path).await?)?
            } else {
                NixExtensions::default()
            };

            let extensions = reqwest::get("https://api.zed.dev/extensions?max_schema_version=1")
                .await?
                .json::<ApiResponse>()
                .await?
                .data;

            let extensions = extensions
                .into_iter()
                .filter(|extension| {
                    // Skip repositories in the config skip list.
                    if config.skip.contains(&extension.repository) {
                        tracing::debug!(
                            repo = extension.repository,
                            "Skipping repository from config"
                        );

                        return false;
                    }

                    // Skip extension that haven't chaned.
                    if let Some(existing) = output
                        .extensions
                        .iter()
                        .find(|existing| existing.id == extension.id)
                    {
                        if existing.published_at >= extension.published_at {
                            tracing::debug!(id = extension.id, "Skipping unchanged extension");
                            return false;
                        }

                        tracing::info!(id = extension.id, "New extension version");

                        // Remove outdated extensions and grammars from output.
                        let grammars = existing.grammars.clone();
                        output
                            .extensions
                            .retain(|existing| existing.id != extension.id);

                        output
                            .grammars
                            .retain(|grammar| !grammars.contains(&grammar.id));
                    }

                    true
                })
                .collect::<Vec<_>>();

            let limit = num_cpus::get() * 2;
            let semaphore = Arc::new(Semaphore::new(limit));

            let mut futures = FuturesUnordered::new();
            for extension in extensions {
                let semaphore = semaphore.clone();
                let future = async move {
                    let _acquire = semaphore.acquire().await.unwrap();
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
                    Ok(None) => (),
                    Err(err) => tracing::error!(
                        err = ?err,
                        "Error processing extension"
                    ),
                }
            }

            tracing::info!("Writing output");
            output.extensions.sort_by(|a, b| a.id.cmp(&b.id));
            output.grammars.sort_by(|a, b| a.id.cmp(&b.id));
            let output = serde_json::to_string_pretty(&output)?;
            fs::write(output_path, output).await?;
        }

        Commands::Populate => {
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
    }

    Ok(())
}
