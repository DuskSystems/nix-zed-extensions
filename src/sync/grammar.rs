use std::collections::BTreeMap;
use std::env::temp_dir;

use futures::stream::{FuturesUnordered, StreamExt};
use tokio::fs;

use crate::{manifest::GrammarManifestEntry, output::Grammar};

use super::{checkout_git_repo, prefetch_git_repo};

pub struct ProcessedGrammars {
    pub grammars: Vec<Grammar>,
    pub ids: Vec<String>,
}

#[tracing::instrument(fields(name = %name))]
pub async fn process_grammars(
    grammars: &BTreeMap<String, GrammarManifestEntry>,
    name: &str,
) -> ProcessedGrammars {
    let mut futures = FuturesUnordered::new();
    for (grammar_name, grammar) in grammars {
        let future = process_grammar(grammar_name.clone(), grammar, name.to_owned());
        futures.push(future);
    }

    let mut processed_grammars = vec![];
    while let Some(result) = futures.next().await {
        match result {
            Ok(Some(grammar)) => {
                processed_grammars.push(grammar);
            }
            Ok(_) => (),
            Err(err) => tracing::error!(
                err = ?err,
                "Error processing grammar"
            ),
        }
    }

    processed_grammars.sort_by(|a, b| a.id.cmp(&b.id));
    let ids = processed_grammars.iter().map(|g| g.id.clone()).collect();

    ProcessedGrammars {
        grammars: processed_grammars,
        ids,
    }
}

#[tracing::instrument(fields(name = %name, extension = %extension))]
async fn process_grammar(
    name: String,
    grammar: &GrammarManifestEntry,
    extension: String,
) -> anyhow::Result<Option<Grammar>> {
    let id = format!("{extension}_{name}");
    let tmp_repo = temp_dir().join(&id);

    let repo = grammar.repository.to_string();
    let rev = grammar.rev.clone();
    checkout_git_repo(&repo, &rev, &tmp_repo).await?;

    let src = prefetch_git_repo(&repo, &rev, false).await?;

    fs::remove_dir_all(&tmp_repo).await?;

    let grammar_root = grammar
        .path
        .clone()
        .map(|s| s.trim_start_matches("./").to_owned());

    Ok(Some(Grammar {
        id,
        name: name.to_string(),
        version: rev,
        src,
        grammar_root,
    }))
}
