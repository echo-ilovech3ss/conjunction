use std::collections::HashSet;
#[cfg(target_os = "linux")]
use std::path::Path;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
#[cfg(target_os = "linux")]
use std::time::Instant;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WatchBackend {
    Inotify,
    PollFallback,
}

#[derive(Debug)]
pub struct AppWatchConfig {
    pub dirs: Vec<PathBuf>,
    pub debounce: Duration,
    pub resync_interval: Duration,
}

impl Default for AppWatchConfig {
    fn default() -> Self {
        Self {
            dirs: Vec::new(),
            debounce: Duration::from_millis(150),
            resync_interval: Duration::from_secs(30),
        }
    }
}

#[cfg(target_os = "linux")]
pub fn run_watch_loop<F>(
    config: AppWatchConfig,
    stop_flag: Arc<AtomicBool>,
    mut on_change: F,
) -> std::io::Result<WatchBackend>
where
    F: FnMut(),
{
    use std::collections::HashMap;
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;

    struct InotifyGuard(i32);
    impl Drop for InotifyGuard {
        fn drop(&mut self) {
            if self.0 >= 0 {
                unsafe { libc::close(self.0) };
            }
        }
    }

    let fd = unsafe { libc::inotify_init1(libc::IN_NONBLOCK | libc::IN_CLOEXEC) };
    if fd < 0 {
        return Err(std::io::Error::last_os_error());
    }
    let _guard = InotifyGuard(fd);

    let root_mask = libc::IN_CREATE
        | libc::IN_DELETE
        | libc::IN_MOVED_FROM
        | libc::IN_MOVED_TO
        | libc::IN_CLOSE_WRITE
        | libc::IN_ATTRIB
        | libc::IN_DELETE_SELF
        | libc::IN_MOVE_SELF;

    let bundle_mask = libc::IN_CREATE
        | libc::IN_DELETE
        | libc::IN_MOVED_FROM
        | libc::IN_MOVED_TO
        | libc::IN_CLOSE_WRITE
        | libc::IN_MODIFY
        | libc::IN_ATTRIB
        | libc::IN_DELETE_SELF
        | libc::IN_MOVE_SELF;

    let mut watched_paths: HashMap<PathBuf, i32> = HashMap::new();

    let add_watch = |path: &Path, mask: u32, watched: &mut HashMap<PathBuf, i32>| {
        if watched.contains_key(path) || !path.exists() {
            return;
        }
        // Watch canonical directory target so symlinks like /Applications -> /var/Applications work reliably
        let watch_target = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
        if watched.contains_key(&watch_target) {
            return;
        }
        if let Ok(c_path) = CString::new(watch_target.as_os_str().as_bytes()) {
            let wd = unsafe { libc::inotify_add_watch(fd, c_path.as_ptr(), mask) };
            if wd >= 0 {
                watched.insert(watch_target, wd);
            }
        }
    };

    let refresh_watches = |watched: &mut HashMap<PathBuf, i32>| {
        // Prune vanished paths
        let dead: Vec<(PathBuf, i32)> = watched
            .iter()
            .filter(|(p, _)| !p.exists())
            .map(|(p, wd)| (p.clone(), *wd))
            .collect();
        for (p, wd) in dead {
            unsafe { libc::inotify_rm_watch(fd, wd) };
            watched.remove(&p);
        }

        for root in &config.dirs {
            if !root.exists() {
                // Also watch parent so if /Applications or ~/Applications appears later we detect it
                if let Some(parent) = root.parent() {
                    if parent.exists() {
                        add_watch(parent, libc::IN_CREATE | libc::IN_MOVED_TO, watched);
                    }
                }
                continue;
            }
            add_watch(root, root_mask, watched);
            if let Ok(entries) = std::fs::read_dir(root) {
                for entry in entries.flatten() {
                    let p = entry.path();
                    if p.is_dir() && p.extension().is_some_and(|e| e == "app") {
                        add_watch(&p, bundle_mask, watched);
                        let contents = p.join("Contents");
                        if contents.is_dir() {
                            add_watch(&contents, bundle_mask, watched);
                            for sub in ["MacOS", "Executable", "Resources", "Frameworks", "WinePrefix"] {
                                let sub_p = contents.join(sub);
                                if sub_p.is_dir() {
                                    add_watch(&sub_p, bundle_mask, watched);
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    refresh_watches(&mut watched_paths);

    let mut pending_since: Option<Instant> = None;
    let mut last_resync = Instant::now();
    let mut incomplete_retry_at: Option<Instant> = None;
    let mut buf = [0u8; 8192];

    while !stop_flag.load(Ordering::Relaxed) {
        let mut pfd = libc::pollfd {
            fd,
            events: libc::POLLIN,
            revents: 0,
        };
        let timeout_ms = if pending_since.is_some() || incomplete_retry_at.is_some() {
            50
        } else {
            250
        };
        let rc = unsafe { libc::poll(&mut pfd, 1, timeout_ms) };
        if rc > 0 && (pfd.revents & libc::POLLIN) != 0 {
            let mut saw_event = false;
            loop {
                let n = unsafe { libc::read(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len()) };
                if n <= 0 {
                    break;
                }
                saw_event = true;
            }
            if saw_event {
                pending_since = Some(Instant::now());
            }
        }

        let now = Instant::now();
        let debounce_elapsed = pending_since.is_some_and(|t| now.duration_since(t) >= config.debounce);
        let retry_elapsed = incomplete_retry_at.is_some_and(|t| now >= t);
        let periodic_elapsed = now.duration_since(last_resync) >= config.resync_interval;

        if debounce_elapsed || retry_elapsed || periodic_elapsed {
            pending_since = None;
            incomplete_retry_at = None;
            last_resync = now;

            refresh_watches(&mut watched_paths);
            on_change();

            // If any *.app directory lacks Contents/Info.toml right now (mid-copy),
            // schedule a quick follow-up check within ~350ms so drag-and-drop settles cleanly.
            if has_partial_bundle(&config.dirs) && !retry_elapsed {
                incomplete_retry_at = Some(Instant::now() + Duration::from_millis(350));
            }
        }
    }

    Ok(WatchBackend::Inotify)
}

#[cfg(not(target_os = "linux"))]
pub fn run_watch_loop<F>(
    config: AppWatchConfig,
    stop_flag: Arc<AtomicBool>,
    mut on_change: F,
) -> std::io::Result<WatchBackend>
where
    F: FnMut(),
{
    let mut prev_snapshot = snapshot_app_dirs(&config.dirs);
    while !stop_flag.load(Ordering::Relaxed) {
        std::thread::sleep(config.debounce.max(Duration::from_millis(200)));
        let curr = snapshot_app_dirs(&config.dirs);
        if curr != prev_snapshot {
            prev_snapshot = curr;
            on_change();
        }
    }
    Ok(WatchBackend::PollFallback)
}

#[allow(dead_code)]
fn has_partial_bundle(dirs: &[PathBuf]) -> bool {
    for root in dirs {
        if let Ok(entries) = std::fs::read_dir(root) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.is_dir() && p.extension().is_some_and(|e| e == "app") {
                    if !p.join("Contents/Info.toml").is_file() {
                        return true;
                    }
                }
            }
        }
    }
    false
}

#[allow(dead_code)]
fn snapshot_app_dirs(dirs: &[PathBuf]) -> HashSet<(PathBuf, u64)> {
    let mut set = HashSet::new();
    for root in dirs {
        if let Ok(entries) = std::fs::read_dir(root) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.is_dir() && p.extension().is_some_and(|e| e == "app") {
                    let info = p.join("Contents/Info.toml");
                    let mtime = std::fs::metadata(&info)
                        .and_then(|m| m.modified())
                        .ok()
                        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                        .map(|d| d.as_nanos() as u64)
                        .unwrap_or(0);
                    set.insert((p, mtime));
                }
            }
        }
    }
    set
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;

    #[test]
    fn test_watch_loop_detects_bundle_create_and_delete() {
        let unique = format!(
            "conj_watch_test_{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        );
        let root = std::env::temp_dir().join(unique);
        let apps_dir = root.join("Applications");
        fs::create_dir_all(&apps_dir).unwrap();

        let hits = Arc::new(AtomicUsize::new(0));
        let hits_cb = Arc::clone(&hits);
        let stop = Arc::new(AtomicBool::new(false));
        let stop_thread = Arc::clone(&stop);

        let cfg = AppWatchConfig {
            dirs: vec![apps_dir.clone()],
            debounce: Duration::from_millis(50),
            resync_interval: Duration::from_secs(60),
        };

        let handle = std::thread::spawn(move || {
            run_watch_loop(cfg, stop_thread, move || {
                hits_cb.fetch_add(1, Ordering::SeqCst);
            })
            .expect("watch loop")
        });

        std::thread::sleep(Duration::from_millis(120));

        // 1. Create a bundle -> watcher should fire
        let app_dir = apps_dir.join("Watched.app");
        fs::create_dir_all(app_dir.join("Contents/MacOS")).unwrap();
        fs::write(app_dir.join("Contents/Info.toml"), "id = \"org.example.w\"\n").unwrap();

        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        while hits.load(Ordering::SeqCst) == 0 && std::time::Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(25));
        }
        let after_create = hits.load(Ordering::SeqCst);
        assert!(after_create >= 1, "expected watch event after bundle creation");

        // 2. Delete the bundle -> watcher should fire again
        fs::remove_dir_all(&app_dir).unwrap();
        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        while hits.load(Ordering::SeqCst) <= after_create && std::time::Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(25));
        }
        let after_delete = hits.load(Ordering::SeqCst);
        assert!(
            after_delete > after_create,
            "expected watch event after bundle deletion (before={}, after={})",
            after_create,
            after_delete
        );

        stop.store(true, Ordering::Relaxed);
        let backend = handle.join().expect("watch thread join");
        #[cfg(target_os = "linux")]
        assert_eq!(backend, WatchBackend::Inotify);
        #[cfg(not(target_os = "linux"))]
        assert_eq!(backend, WatchBackend::PollFallback);

        let _ = fs::remove_dir_all(&root);
    }

    use std::fs;
}
