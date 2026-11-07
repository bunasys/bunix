// Compiles the C++ shim (shim/shim.cpp) into a static library and links it,
// with aquamarine and what it needs, as pkg-config describes them.  No
// build-time crates: the compiler and pkg-config are called directly.
use std::env;
use std::process::Command;

// (pixman-1: hyprutils's headers include pixman.h, and its .pc does not say so)
const PACKAGES: &[&str] = &["aquamarine", "hyprutils", "pixman-1", "libdrm", "gbm"];

fn pkg_config(flag: &str) -> Vec<String> {
    let output = Command::new("pkg-config")
        .arg(flag)
        .args(PACKAGES)
        .output()
        .expect("running pkg-config");
    assert!(output.status.success(), "pkg-config {flag} failed: {}", String::from_utf8_lossy(&output.stderr));
    String::from_utf8(output.stdout)
        .expect("pkg-config output")
        .split_whitespace()
        .map(String::from)
        .collect()
}

fn run(command: &mut Command) {
    let status = command.status().unwrap_or_else(|error| panic!("running {command:?}: {error}"));
    assert!(status.success(), "{command:?} failed");
}

fn main() {
    println!("cargo:rerun-if-changed=shim/shim.cpp");
    println!("cargo:rerun-if-changed=shim/shim.h");
    println!("cargo:rerun-if-env-changed=CXX");
    println!("cargo:rerun-if-env-changed=CXXFLAGS");
    println!("cargo:rerun-if-env-changed=PKG_CONFIG_PATH");

    let out_dir = env::var("OUT_DIR").expect("OUT_DIR");
    let object = format!("{out_dir}/shim.o");
    let library = format!("{out_dir}/libshim.a");
    let compiler = env::var("CXX").unwrap_or_else(|_| "c++".to_string());

    // The build's own flags (include/system.yml's hardening) come first;
    // aquamarine's headers need C++23
    let build_flags = env::var("CXXFLAGS").unwrap_or_default();
    run(Command::new(compiler)
        .args(build_flags.split_whitespace())
        .args(["-std=c++23", "-fPIC", "-Wall", "-c", "shim/shim.cpp", "-o", &object])
        .args(pkg_config("--cflags")));
    run(Command::new("ar").args(["crs", &library, &object]));

    println!("cargo:rustc-link-search=native={out_dir}");
    println!("cargo:rustc-link-lib=static=shim");
    for flag in pkg_config("--libs") {
        if let Some(name) = flag.strip_prefix("-l") {
            println!("cargo:rustc-link-lib=dylib={name}");
        } else if let Some(path) = flag.strip_prefix("-L") {
            println!("cargo:rustc-link-search=native={path}");
        }
    }
    println!("cargo:rustc-link-lib=dylib=stdc++");
}
