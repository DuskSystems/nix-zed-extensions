use std::path::PathBuf;

use wasmparser::{Parser, Payload};

pub fn extract_zed_api_version(wasm: &PathBuf) -> anyhow::Result<String> {
    let bytes = std::fs::read(wasm)?;
    for part in Parser::new(0).parse_all(&bytes) {
        if let Payload::CustomSection(section) = part? {
            if section.name() == "zed:api-version" {
                let data = section.data();

                let major = u16::from_be_bytes([data[0], data[1]]);
                let minor = u16::from_be_bytes([data[2], data[3]]);
                let patch = u16::from_be_bytes([data[4], data[5]]);

                return Ok(format!("{major}.{minor}.{patch}"));
            }
        }
    }

    anyhow::bail!("Failed to parse WASM extension version")
}
