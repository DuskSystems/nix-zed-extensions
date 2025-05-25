use std::env::{current_dir, temp_dir};
use std::path::{Path, PathBuf};

use futures::stream::{FuturesUnordered, StreamExt};
use tokio::fs;
use tokio::process::Command;

use crate::manifest::{ExtensionManifest, GrammarManifestEntry};
use crate::output::{CargoLock, Extension, ExtensionKind, Grammar, Source};
use crate::registry::RegistryExtension;

#[tracing::instrument(
    skip(extension),
    fields(name = %extension.name, version = %extension.version, repo = %extension.repository, rev = %extension.rev)
)]
pub async fn process_extension(
    extension: RegistryExtension,
) -> anyhow::Result<Option<(Extension, Vec<Grammar>)>> {
    tracing::info!("Synching extension");

    let name = extension.name.to_string();
    let repo = extension.repository.to_string();
    tracing::info!("Checking out repository");

    let tmp_repo = temp_dir().join(&name);
    if tmp_repo.exists() {
        fs::remove_dir_all(&tmp_repo).await?;
    }

    let clone = Command::new("git")
        .args(["clone", &repo, &tmp_repo.to_string_lossy()])
        .output()
        .await?;

    if !clone.status.success() {
        anyhow::bail!("Failed to clone")
    }

    let checkout = Command::new("git")
        .args(["checkout", &extension.rev])
        .current_dir(&tmp_repo)
        .output()
        .await?;

    if !checkout.status.success() {
        anyhow::bail!("Failed to checkout")
    }

    let (extension_dir, manifest) = if let Some(path) = &extension.path {
        let extension_dir = tmp_repo.join(path);
        (extension_dir.clone(), extension_dir.join("extension.toml"))
    } else {
        (tmp_repo.clone(), tmp_repo.join("extension.toml"))
    };

    if fs::metadata(&manifest).await.is_err() {
        tracing::error!("Missing extension.toml");
        fs::remove_dir_all(&tmp_repo).await?;
        return Ok(None);
    }

    let cargo = extension_dir.join("Cargo.toml");
    let lockfile = if extension.path.is_some() {
        tmp_repo.join("Cargo.lock")
    } else {
        extension_dir.join("Cargo.lock")
    };

    let generated_dir = Path::new("generated");
    if !generated_dir.exists() {
        fs::create_dir(generated_dir).await?;
    }

    let stored_lockfile = generated_dir.join(format!("{name}.lock"));
    let mut altered_lockfile = false;

    if cargo.exists() && !lockfile.exists() {
        tracing::info!("Generating Cargo.lock");

        let generate_lockfile = Command::new("cargo")
            .args(["generate-lockfile"])
            .current_dir(&tmp_repo)
            .output()
            .await?;

        if !generate_lockfile.status.success() {
            tracing::error!("Failed to generate Cargo.lock");
            fs::remove_dir_all(&tmp_repo).await?;
            return Ok(None);
        }

        fs::copy(&lockfile, &stored_lockfile).await?;
        altered_lockfile = true;
    }

    // HACK: Special treatment to fix duplicate dependency in lockfile
    if repo == "https://github.com/zed-industries/zed" {
        tracing::info!("Patching Cargo.lock");

        let patch = current_dir()?.join("patches/zed-duplicate-reqwest.patch");
        let apply = Command::new("git")
            .args(["apply", &patch.to_string_lossy()])
            .current_dir(&tmp_repo)
            .output()
            .await?;

        if !apply.status.success() {
            anyhow::bail!("Failed to patch Cargo.lock");
        }

        fs::copy(&lockfile, &stored_lockfile).await?;
        altered_lockfile = true;
    }

    if !altered_lockfile && stored_lockfile.exists() {
        tracing::info!("Removing old generated lockfile");
        fs::remove_file(&stored_lockfile).await?;
    }

    let prefetch = Command::new("nix-prefetch-git")
        .args(["--url", &repo, "--rev", &extension.rev, "--quiet"])
        .output()
        .await?;

    if !prefetch.status.success() {
        anyhow::bail!("Failed to pre-fetch repository")
    }

    let src: Source = serde_json::from_slice(&prefetch.stdout)?;
    tracing::info!(src = ?src, "Pre-fetched git hash");

    tracing::debug!("Reading extension manifest");
    let manifest = fs::read_to_string(manifest).await?;
    let manifest: ExtensionManifest = toml::from_str(&manifest)?;

    let mut futures = FuturesUnordered::new();
    for (grammar_name, grammar) in manifest.grammars.iter() {
        let future = process_grammar(grammar_name.clone(), grammar, name.clone());
        futures.push(future);
    }

    let mut grammars = vec![];
    while let Some(result) = futures.next().await {
        match result {
            Ok(Some(grammar)) => {
                grammars.push(grammar);
            }
            Ok(None) => (),
            Err(err) => tracing::error!(
                err = ?err,
                "Error processing grammar"
            ),
        }
    }

    let kind = if cargo.exists() {
        process_rust_extension(&name, &lockfile, altered_lockfile).await?
    } else {
        ExtensionKind::Plain
    };

    fs::remove_dir_all(&tmp_repo).await?;
    grammars.sort_by(|a, b| a.id.cmp(&b.id));

    Ok(Some((
        Extension {
            name,
            version: manifest.version,
            src,
            extension_root: extension.path,
            grammars: grammars.iter().map(|grammar| grammar.id.clone()).collect(),
            kind,
        },
        grammars,
    )))
}

#[tracing::instrument(fields(name = %name, extension = %extension))]
async fn process_grammar(
    name: String,
    grammar: &GrammarManifestEntry,
    extension: String,
) -> anyhow::Result<Option<Grammar>> {
    let id = format!("{extension}_{name}");
    let tmp_repo = temp_dir().join(&id);
    if tmp_repo.exists() {
        fs::remove_dir_all(&tmp_repo).await?;
    }

    let repo = grammar.repository.to_string();
    let rev = grammar.rev.clone();
    tracing::info!(repo = repo, rev = rev, "Checking out grammar repository");

    let clone = Command::new("git")
        .args(["clone", &repo, &tmp_repo.to_string_lossy()])
        .output()
        .await?;

    if !clone.status.success() {
        anyhow::bail!("Failed to clone")
    }

    let fetch = Command::new("git")
        .args(["fetch", "origin", &rev])
        .current_dir(&tmp_repo)
        .output()
        .await?;

    if !fetch.status.success() {
        anyhow::bail!("Failed to fetch")
    }

    let checkout = Command::new("git")
        .args(["checkout", &rev])
        .current_dir(&tmp_repo)
        .output()
        .await?;

    if !checkout.status.success() {
        anyhow::bail!("Failed to checkout revision")
    }

    let prefetch = Command::new("nix-prefetch-git")
        .args(["--url", &repo, "--rev", &rev, "--quiet"])
        .output()
        .await?;

    if !prefetch.status.success() {
        anyhow::bail!("Failed to pre-fetch grammar repository")
    }

    let src: Source = serde_json::from_slice(&prefetch.stdout)?;
    tracing::info!(src = ?src, "Pre-fetched git hash");

    fs::remove_dir_all(&tmp_repo).await?;

    Ok(Some(Grammar {
        id,
        name: name.to_string(),
        version: rev,
        src,
    }))
}

#[tracing::instrument(fields(name = %name))]
async fn process_rust_extension(
    name: &str,
    lockfile: &Path,
    generated_lockfile: bool,
) -> anyhow::Result<ExtensionKind> {
    let tmp_vendor = temp_dir().join(format!("{name}_vendor"));
    if tmp_vendor.exists() {
        fs::remove_dir_all(&tmp_vendor).await?;
    }

    let vendor = Command::new("fetch-cargo-vendor-util")
        .args([
            "create-vendor-staging",
            &lockfile.to_string_lossy(),
            &tmp_vendor.to_string_lossy(),
        ])
        .output()
        .await?;

    if !vendor.status.success() {
        anyhow::bail!("Failed to vendor cargo dependencies")
    }

    let cargo_hash = Command::new("nix-hash")
        .args(["--type", "sha256", "--sri", &tmp_vendor.to_string_lossy()])
        .output()
        .await?;

    if !cargo_hash.status.success() {
        anyhow::bail!("Failed to hash cargo dependencies")
    }

    let cargo_hash = String::from_utf8_lossy(&cargo_hash.stdout)
        .trim()
        .to_string();

    tracing::info!(hash = ?cargo_hash, "Pre-fetched cargo hash");

    let cargo_lock: Option<CargoLock> = if generated_lockfile {
        Some(CargoLock {
            lock_file: PathBuf::from(format!("/generated/{name}.lock")),
        })
    } else {
        None
    };

    Ok(ExtensionKind::Rust {
        cargo_hash,
        cargo_lock,
    })
}
