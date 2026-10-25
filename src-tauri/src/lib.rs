//! Trim Playlist desktop shell.
//!
//! The window opens on a small splash page that polls `server_url`. The real
//! UI is the existing player web app, served by the bundled Python sidecar
//! (PyInstaller build of pc/app/trim_playlist_server_main.py). The shell
//! starts that server, waits for its TRIM_SERVER_READY line on stdout, then
//! points the webview at the printed URL. Closing the window stops the server
//! and its yt-dlp / ffmpeg children.

use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::thread;

use tauri::{Manager, RunEvent, State};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

const CREATE_NO_WINDOW: u32 = 0x0800_0000;
const SERVER_PORT_ARG: &str = "8765";

struct ServerState {
  child: Mutex<Option<Child>>,
  url: Mutex<Option<String>>,
}

// Resources keep their src-tauri-relative path: "resources/server/..."
// next to the exe (install root, portable layout, and macOS Contents/Resources).
fn sidecar_dir(resource_dir: &std::path::Path) -> PathBuf {
  resource_dir.join("resources").join("server").join("TrimPlaylistServer")
}

fn sidecar_exe(resource_dir: &std::path::Path) -> PathBuf {
  #[cfg(windows)]
  let name = "TrimPlaylistServer.exe";
  #[cfg(not(windows))]
  let name = "TrimPlaylistServer";
  sidecar_dir(resource_dir).join(name)
}

fn spawn_server(app: &tauri::AppHandle) {
  let Ok(resource_dir) = app.path().resource_dir() else {
    eprintln!("Trim Playlist: cannot resolve resource dir");
    return;
  };
  let exe = sidecar_exe(&resource_dir);
  if !exe.is_file() {
    eprintln!("Trim Playlist: server sidecar missing at {}", exe.display());
    return;
  }

  let mut cmd = Command::new(&exe);
  cmd
    .arg("--host")
    .arg("127.0.0.1")
    .arg("--port")
    .arg(SERVER_PORT_ARG)
    // The player UI reads this via /api/shell and hides web-only links.
    .env("TRIM_SHELL", "desktop")
    .stdout(Stdio::piped())
    .stderr(Stdio::piped())
    .stdin(Stdio::null());
  #[cfg(windows)]
  cmd.creation_flags(CREATE_NO_WINDOW);

  let mut child = match cmd.spawn() {
    Ok(child) => child,
    Err(e) => {
      eprintln!("Trim Playlist: could not start server: {e}");
      return;
    }
  };

  if let Some(stdout) = child.stdout.take() {
    let app = app.clone();
    thread::spawn(move || {
      for line in BufReader::new(stdout).lines().map_while(Result::ok) {
        if let Some(url) = line.strip_prefix("TRIM_SERVER_READY url=") {
          let state = app.state::<ServerState>();
          *state.url.lock().unwrap_or_else(|e| e.into_inner()) = Some(url.to_string());
          break;
        }
      }
    });
  }
  // Drain stderr so the pipe never fills and blocks the server.
  if let Some(stderr) = child.stderr.take() {
    thread::spawn(move || {
      for line in BufReader::new(stderr).lines().map_while(Result::ok) {
        eprintln!("[trim-server] {line}");
      }
    });
  }

  let state = app.state::<ServerState>();
  *state.child.lock().unwrap_or_else(|e| e.into_inner()) = Some(child);
}

fn kill_server(state: &ServerState) {
  let Some(mut child) = state.child.lock().unwrap_or_else(|e| e.into_inner()).take() else {
    return;
  };
  #[cfg(windows)]
  {
    // The server spawns yt-dlp / ffmpeg children; end the whole tree.
    let mut killer = Command::new("taskkill");
    killer
      .args(["/PID", &child.id().to_string(), "/T", "/F"])
      .stdout(Stdio::null())
      .stderr(Stdio::null());
    killer.creation_flags(CREATE_NO_WINDOW);
    let _ = killer.status();
  }
  #[cfg(not(windows))]
  {
    let _ = child.kill();
  }
  let _ = child.wait();
}

#[tauri::command]
fn server_url(state: State<'_, ServerState>) -> Option<String> {
  state.url.lock().unwrap_or_else(|e| e.into_inner()).clone()
}

pub fn run() {
  let app = tauri::Builder::default()
    .manage(ServerState {
      child: Mutex::new(None),
      url: Mutex::new(None),
    })
    .setup(|app| {
      spawn_server(app.handle());
      Ok(())
    })
    .invoke_handler(tauri::generate_handler![server_url])
    .build(tauri::generate_context!())
    .expect("error while building Trim Playlist");

  app.run(|_app, event| {
    if matches!(event, RunEvent::Exit | RunEvent::ExitRequested { .. }) {
      kill_server(&_app.state::<ServerState>());
    }
  });
}
