use anyhow::{Context, Result};
use winreg::enums::*;
use winreg::RegKey;

use crate::policy::{self, PolicyEntry, RegValue};

const EDGE_POLICY_PATH: &str = r"SOFTWARE\Policies\Microsoft\Edge";

pub fn apply(entries: &[PolicyEntry]) -> Result<()> {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let (base, _) = hkcu
        .create_subkey(EDGE_POLICY_PATH)
        .context("Failed to open/create Edge policy key")?;

    // Delete-then-recreate list subkeys to avoid stale numbered entries
    for subkey_name in policy::MANAGED_SUBKEYS {
        let _ = base.delete_subkey_all(subkey_name);
    }

    for entry in entries {
        let key = if entry.subkey.is_empty() {
            &base
        } else {
            &hkcu
                .create_subkey(&format!(r"{}\{}", EDGE_POLICY_PATH, entry.subkey))
                .with_context(|| format!("Failed to create subkey: {}", entry.subkey))?
                .0
        };

        match &entry.value {
            RegValue::Dword(v) => key
                .set_value(&entry.name, v)
                .with_context(|| format!("Failed to set DWORD: {}", entry.name))?,
            RegValue::Sz(v) => key
                .set_value(&entry.name, v)
                .with_context(|| format!("Failed to set SZ: {}", entry.name))?,
        }
    }

    Ok(())
}

pub fn dump() -> Result<()> {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);

    let base = match hkcu.open_subkey(EDGE_POLICY_PATH) {
        Ok(k) => k,
        Err(_) => {
            println!("No HKCU Edge policies found.");
            return Ok(());
        }
    };

    println!(r"HKCU\{}", EDGE_POLICY_PATH);
    println!();
    dump_key(&base, "")?;

    // Enumerate subkeys
    for name in base.enum_keys().filter_map(|r| r.ok()) {
        if let Ok(sub) = base.open_subkey(&name) {
            println!("  [{name}]");
            dump_key(&sub, "    ")?;
        }
    }

    Ok(())
}

fn dump_key(key: &RegKey, indent: &str) -> Result<()> {
    for (name, value) in key.enum_values().filter_map(|r| r.ok()) {
        let display = match value.vtype {
            REG_DWORD => {
                let v: u32 = key.get_value(&name).unwrap_or(0);
                format!("DWORD({v})")
            }
            REG_SZ | REG_EXPAND_SZ => {
                let v: String = key.get_value(&name).unwrap_or_default();
                format!("\"{v}\"")
            }
            _ => format!("{:?}", value.bytes),
        };
        println!("{indent}{name} = {display}");
    }
    Ok(())
}

pub fn clean() -> Result<()> {
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);

    let base = match hkcu.open_subkey_with_flags(EDGE_POLICY_PATH, KEY_ALL_ACCESS) {
        Ok(k) => k,
        Err(_) => {
            println!("No HKCU Edge policies found, nothing to clean.");
            return Ok(());
        }
    };

    // Remove managed top-level values
    for name in policy::MANAGED_VALUES {
        match base.delete_value(name) {
            Ok(()) => println!("  Removed {name}"),
            Err(_) => {}
        }
    }

    // Remove managed subkeys
    for subkey_name in policy::MANAGED_SUBKEYS {
        match base.delete_subkey_all(subkey_name) {
            Ok(()) => println!("  Removed subkey {subkey_name}"),
            Err(_) => {}
        }
    }

    // If the Edge policy key is now empty, remove it too
    let has_values = base.enum_values().next().is_some();
    let has_subkeys = base.enum_keys().next().is_some();
    drop(base);

    if !has_values && !has_subkeys {
        let _ = hkcu.delete_subkey(EDGE_POLICY_PATH);
        println!("  Removed empty Edge policy key");
    }

    Ok(())
}

/// Warn if any HKLM policies overlap with what we're about to write.
pub fn check_hklm_conflicts(entries: &[PolicyEntry]) {
    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    let base = match hklm.open_subkey(EDGE_POLICY_PATH) {
        Ok(k) => k,
        Err(_) => return,
    };

    let mut warned = false;
    for entry in entries {
        if !entry.subkey.is_empty() {
            continue;
        }
        let exists: Result<String, _> = base.get_value(&entry.name);
        let exists_dword: Result<u32, _> = base.get_value(&entry.name);
        if exists.is_ok() || exists_dword.is_ok() {
            if !warned {
                eprintln!("Warning: The following HKLM policies overlap (HKLM takes precedence):");
                warned = true;
            }
            eprintln!("  HKLM: {}", entry.name);
        }
    }
    if warned {
        eprintln!();
    }
}
