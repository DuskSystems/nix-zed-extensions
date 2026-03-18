use std::path::Path;

use smol::fs;
use smol::stream::StreamExt;

/// Copies files and directories from `src` to `dest`, preserving relative paths.
pub async fn copy_items(src: &[impl AsRef<Path> + Sync], dest: &Path) -> anyhow::Result<()> {
    for path in src {
        let path = path.as_ref();
        let to = dest.join(path);

        if path.is_dir() {
            copy_dir(path, &to).await?;
        } else {
            if let Some(parent) = to.parent() {
                fs::create_dir_all(parent).await?;
            }

            fs::copy(path, &to).await?;
        }
    }

    Ok(())
}

/// Recursively copies a directory from `src` to `dest`.
async fn copy_dir(src: &Path, dest: &Path) -> anyhow::Result<()> {
    fs::create_dir_all(dest).await?;

    let mut read_dir = fs::read_dir(src).await?;
    while let Some(entry) = read_dir.try_next().await? {
        let path = entry.path();
        let to = dest.join(entry.file_name());

        if path.is_dir() {
            Box::pin(copy_dir(&path, &to)).await?;
        } else {
            fs::copy(&path, &to).await?;
        }
    }

    Ok(())
}
