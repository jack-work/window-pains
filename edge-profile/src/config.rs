use std::path::Path;

use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub search: Option<SearchConfig>,
    pub extensions: Option<toml::map::Map<String, toml::Value>>,
    pub browser: Option<BrowserConfig>,
    pub privacy: Option<PrivacyConfig>,
}

#[derive(Debug, Deserialize)]
pub struct SearchConfig {
    pub provider: Option<String>,
    pub search_url: Option<String>,
    pub suggest_url: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct BrowserConfig {
    pub restore_on_startup: Option<String>,
    pub show_home_button: Option<bool>,
    pub favorites_bar: Option<bool>,
    pub hide_first_run: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct PrivacyConfig {
    pub tracking_prevention: Option<String>,
    pub password_manager: Option<bool>,
    pub autofill_credit_card: Option<bool>,
    pub autofill_address: Option<bool>,
}

pub fn load(path: Option<&Path>) -> Result<Config> {
    let path = match path {
        Some(p) => p.to_owned(),
        None => default_config_path()?,
    };

    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("Failed to read config: {}", path.display()))?;

    let config: Config =
        toml::from_str(&text).with_context(|| format!("Failed to parse config: {}", path.display()))?;

    Ok(config)
}

fn default_config_path() -> Result<std::path::PathBuf> {
    let home = dirs::home_dir().context("Cannot determine home directory")?;
    Ok(home.join(".edge-profile").join("config.toml"))
}
