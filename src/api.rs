use serde::Deserialize;

#[derive(Deserialize, Debug, Clone)]
pub struct ApiResponse {
    pub data: Vec<ApiExtension>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct ApiExtension {
    pub id: String,
    pub name: String,
    pub version: String,
    pub description: String,
    pub authors: Vec<String>,
    pub repository: String,
    pub schema_version: i32,
    pub wasm_api_version: Option<String>,
    pub provides: Vec<String>,
    pub published_at: String,
    pub download_count: i64,
}
