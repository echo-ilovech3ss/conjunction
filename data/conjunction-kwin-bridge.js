// Conjunction KWin Script: Bridge window events to Conjunction Shell via D-Bus
// Compatible with KWin 6 / Wayland

function sendWindowActivated(win) {
    if (!win) return;
    var appId = win.desktopFileName || win.resourceClass || win.appId || "";
    var title = win.caption || "";
    var id = win.internalId ? win.internalId.toString() : "";
    var pid = win.pid || 0;
    var isFs = win.fullScreen || false;

    callDBus(
        "org.conjunction.Shell",
        "/org/conjunction/Shell/WindowManager",
        "org.conjunction.Shell.WindowManager",
        "WindowActivated",
        id, title, appId, pid, isFs
    );
}

function sendWindowAdded(win) {
    if (!win) return;
    var appId = win.desktopFileName || win.resourceClass || win.appId || "";
    var title = win.caption || "";
    var id = win.internalId ? win.internalId.toString() : "";
    var pid = win.pid || 0;
    var isFs = win.fullScreen || false;

    callDBus(
        "org.conjunction.Shell",
        "/org/conjunction/Shell/WindowManager",
        "org.conjunction.Shell.WindowManager",
        "WindowAdded",
        id, title, appId, pid, isFs
    );
}

function sendWindowRemoved(win) {
    if (!win) return;
    var id = win.internalId ? win.internalId.toString() : "";

    callDBus(
        "org.conjunction.Shell",
        "/org/conjunction/Shell/WindowManager",
        "org.conjunction.Shell.WindowManager",
        "WindowRemoved",
        id
    );
}

// Connect KWin 6 workspace signals
if (typeof workspace !== "undefined") {
    workspace.windowAdded.connect(sendWindowAdded);
    workspace.windowRemoved.connect(sendWindowRemoved);
    workspace.windowActivated.connect(sendWindowActivated);

    // Initial enumeration of all open windows
    var allWins = workspace.windowList();
    for (var i = 0; i < allWins.length; ++i) {
        sendWindowAdded(allWins[i]);
    }
    if (workspace.activeWindow) {
        sendWindowActivated(workspace.activeWindow);
    }
}
