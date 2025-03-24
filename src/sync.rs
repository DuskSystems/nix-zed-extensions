use std::env::temp_dir;
use std::path::Path;

use futures::stream::{FuturesUnordered, StreamExt};
use tokio::fs;
use tokio::process::Command;

use crate::api::ApiExtension;
use crate::manifest::{ExtensionManifest, GrammarManifestEntry};
use crate::output::{Extension, ExtensionKind, Grammar, Source};

#[tracing::instrument(skip(extension), fields(id = %extension.id, repo = %extension.repository))]
pub async fn process_extension(
    extension: ApiExtension,
) -> anyhow::Result<Option<(Extension, Vec<Grammar>)>> {
    tracing::info!("Synching extension");

    let id = extension.id.to_string();
    let repo = extension.repository.to_string();
    tracing::info!("Checking out repository");

    let tmp_repo = temp_dir().join(&id);
    if tmp_repo.exists() {
        fs::remove_dir_all(&tmp_repo).await?;
    }

    let response = reqwest::get(&repo).await?;
    if !response.status().is_success() {
        tracing::error!("Repository does not exist or is not accessible");
        return Ok(None);
    }

    let clone = Command::new("git")
        .args(["clone", "--depth", "1", &repo, &tmp_repo.to_string_lossy()])
        .output()
        .await?;

    if !clone.status.success() {
        anyhow::bail!("Failed to clone")
    }

    let rev = Command::new("git")
        .args(["rev-parse", "HEAD"])
        .current_dir(&tmp_repo)
        .output()
        .await?;

    if !rev.status.success() {
        anyhow::bail!("Failed to extract revision")
    }

    let rev = String::from_utf8(rev.stdout)?.trim().to_string();
    tracing::info!(rev = rev, "Current revision");

    let manifest = &tmp_repo.join("extension.toml");
    if fs::metadata(manifest).await.is_err() {
        tracing::error!("Missing extension.toml");
        fs::remove_dir_all(&tmp_repo).await?;
        return Ok(None);
    }

    let cargo = &tmp_repo.join("Cargo.toml");
    let lockfile = &tmp_repo.join("Cargo.lock");
    if cargo.exists() && !lockfile.exists() {
        tracing::error!("Missing Cargo.lock");
        fs::remove_dir_all(&tmp_repo).await?;
        return Ok(None);
    }

    let prefetch = Command::new("nix-prefetch-git")
        .args(["--url", &repo, "--rev", &rev, "--quiet"])
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
    for (name, grammar) in manifest.grammars.iter() {
        let future = process_grammar(name.clone(), grammar, id.clone());
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
        process_rust_extension(&id, lockfile).await?
    } else {
        ExtensionKind::Plain
    };

    fs::remove_dir_all(&tmp_repo).await?;
    grammars.sort_by(|a, b| a.id.cmp(&b.id));

    Ok(Some((
        Extension {
            id,
            version: manifest.version,
            src,
            grammars: grammars.iter().map(|grammar| grammar.id.clone()).collect(),
            kind,
            published_at: extension.published_at,
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

    let response = reqwest::get(&repo).await?;
    if !response.status().is_success() {
        tracing::error!(
            repo = repo,
            "Grammar repository does not exist or is not accessible"
        );

        return Ok(None);
    }

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

#[tracing::instrument(fields(id = %id))]
async fn process_rust_extension(id: &str, lockfile: &Path) -> anyhow::Result<ExtensionKind> {
    let tmp_vendor = temp_dir().join(format!("{id}_vendor"));
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

    Ok(ExtensionKind::Rust {
        use_fetch_cargo_vendor: true,
        cargo_hash,
    })
}
