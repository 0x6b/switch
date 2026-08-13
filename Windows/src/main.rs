#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]
#[cfg(target_os = "windows")]
use windows_app::run;
#[cfg(target_os = "windows")]
use windows_app::show_error;

#[cfg(any(target_os = "windows", test))]
mod config;
#[cfg(any(target_os = "windows", test))]
mod decoder;

#[cfg(target_os = "windows")]
mod windows_app;

#[cfg(target_os = "windows")]
fn main() {
    if let Err(message) = run() {
        show_error(&message);
    }
}

#[cfg(not(target_os = "windows"))]
fn main() {
    eprintln!("Switch for Windows can only run on Windows.");
}
