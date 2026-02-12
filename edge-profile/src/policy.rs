use std::fmt;

use crate::config::Config;

/// Registry value types we write.
#[derive(Debug, Clone)]
pub enum RegValue {
    Dword(u32),
    Sz(String),
}

/// A single registry entry to write.
#[derive(Debug, Clone)]
pub struct PolicyEntry {
    /// Subkey path relative to `HKCU\SOFTWARE\Policies\Microsoft\Edge`.
    /// Empty string means the Edge key itself.
    pub subkey: String,
    pub name: String,
    pub value: RegValue,
}

impl fmt::Display for PolicyEntry {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let path = if self.subkey.is_empty() {
            self.name.clone()
        } else {
            format!(r"{}\{}", self.subkey, self.name)
        };
        match &self.value {
            RegValue::Dword(v) => write!(f, "{path} = DWORD({v})"),
            RegValue::Sz(v) => write!(f, "{path} = \"{v}\""),
        }
    }
}

/// All top-level value names this tool may write (used by `clean`).
pub const MANAGED_VALUES: &[&str] = &[
    "DefaultSearchProviderEnabled",
    "DefaultSearchProviderName",
    "DefaultSearchProviderSearchURL",
    "DefaultSearchProviderSuggestURL",
    "RestoreOnStartup",
    "ShowHomeButton",
    "FavoritesBarEnabled",
    "HideFirstRunExperience",
    "TrackingPrevention",
    "PasswordManagerEnabled",
    "AutofillCreditCardEnabled",
    "AutofillAddressEnabled",
];

/// Subkeys this tool may create (used by `clean`).
pub const MANAGED_SUBKEYS: &[&str] = &["ExtensionInstallForcelist"];

const EDGE_UPDATE_URL: &str =
    "https://edge.microsoft.com/extensionwebstorebase/v1/crx";
const CHROME_UPDATE_URL: &str =
    "https://clients2.google.com/service/update2/crx";

pub fn build_entries(cfg: &Config) -> Vec<PolicyEntry> {
    let mut entries = Vec::new();

    if let Some(ref search) = cfg.search {
        entries.push(dword("", "DefaultSearchProviderEnabled", 1));

        if let Some(ref name) = search.provider {
            entries.push(sz("", "DefaultSearchProviderName", name));
        }
        if let Some(ref url) = search.search_url {
            entries.push(sz("", "DefaultSearchProviderSearchURL", url));
        }
        if let Some(ref url) = search.suggest_url {
            entries.push(sz("", "DefaultSearchProviderSuggestURL", url));
        }
    }

    if let Some(ref exts) = cfg.extensions {
        for (i, (_key, val)) in exts.iter().enumerate() {
            if let Some(s) = val.as_str() {
                let entry_value = resolve_extension(s);
                entries.push(sz(
                    "ExtensionInstallForcelist",
                    &(i + 1).to_string(),
                    &entry_value,
                ));
            }
        }
    }

    if let Some(ref browser) = cfg.browser {
        if let Some(ref mode) = browser.restore_on_startup {
            let dword_val = match mode.as_str() {
                "new_tab" => 5,
                "previous_session" => 1,
                "urls" => 4,
                _ => 5,
            };
            entries.push(dword("", "RestoreOnStartup", dword_val));
        }
        if let Some(v) = browser.show_home_button {
            entries.push(dword("", "ShowHomeButton", v as u32));
        }
        if let Some(v) = browser.favorites_bar {
            entries.push(dword("", "FavoritesBarEnabled", v as u32));
        }
        if let Some(v) = browser.hide_first_run {
            entries.push(dword("", "HideFirstRunExperience", v as u32));
        }
    }

    if let Some(ref privacy) = cfg.privacy {
        if let Some(ref level) = privacy.tracking_prevention {
            let val = match level.as_str() {
                "off" => 0,
                "basic" => 1,
                "balanced" => 2,
                "strict" => 3,
                _ => 2,
            };
            entries.push(dword("", "TrackingPrevention", val));
        }
        if let Some(v) = privacy.password_manager {
            entries.push(dword("", "PasswordManagerEnabled", v as u32));
        }
        if let Some(v) = privacy.autofill_credit_card {
            entries.push(dword("", "AutofillCreditCardEnabled", v as u32));
        }
        if let Some(v) = privacy.autofill_address {
            entries.push(dword("", "AutofillAddressEnabled", v as u32));
        }
    }

    entries
}

/// Parse `edge:ID` or `chrome:ID` into `ID;update_url`.
fn resolve_extension(spec: &str) -> String {
    let (id, url) = if let Some(id) = spec.strip_prefix("edge:") {
        (id, EDGE_UPDATE_URL)
    } else if let Some(id) = spec.strip_prefix("chrome:") {
        (id, CHROME_UPDATE_URL)
    } else {
        // Bare ID — assume Edge store
        (spec, EDGE_UPDATE_URL)
    };
    format!("{id};{url}")
}

fn dword(subkey: &str, name: &str, value: u32) -> PolicyEntry {
    PolicyEntry {
        subkey: subkey.to_owned(),
        name: name.to_owned(),
        value: RegValue::Dword(value),
    }
}

fn sz(subkey: &str, name: &str, value: &str) -> PolicyEntry {
    PolicyEntry {
        subkey: subkey.to_owned(),
        name: name.to_owned(),
        value: RegValue::Sz(value.to_owned()),
    }
}
