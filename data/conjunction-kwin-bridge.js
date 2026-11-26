// Conjunction KWin Script: Bridge window, minimized, desktop, and shortcut events to Conjunction Shell via D-Bus
// Compatible with KWin 6 / Wayland

function sendWindowState(method, win) {
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
        method,
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

function connectWindowSignals(win) {
    if (!win) return;
    win.captionChanged.connect(function () {
        sendWindowState("WindowActivated", win);
    });
    win.fullScreenChanged.connect(function () {
        sendWindowState("WindowActivated", win);
    });
    win.minimizedChanged.connect(function () {
        var id = win.internalId ? win.internalId.toString() : "";
        var title = win.caption || "";
        var appId = win.desktopFileName || win.resourceClass || win.appId || "";
        callDBus(
            "org.conjunction.Shell",
            "/org/conjunction/Shell/WindowManager",
            "org.conjunction.Shell.WindowManager",
            "WindowMinimizedChanged",
            id, title, appId, Boolean(win.minimized)
        );
    });
}

if (typeof workspace !== "undefined") {
    workspace.windowAdded.connect(function (win) {
        connectWindowSignals(win);
        sendWindowState("WindowAdded", win);
    });
    workspace.windowRemoved.connect(sendWindowRemoved);
    workspace.windowActivated.connect(function (win) {
        sendWindowState("WindowActivated", win);
    });

    var allWins = workspace.windowList();
    for (var i = 0; i < allWins.length; ++i) {
        connectWindowSignals(allWins[i]);
        sendWindowState("WindowAdded", allWins[i]);
    }
    if (workspace.activeWindow) {
        sendWindowState("WindowActivated", workspace.activeWindow);
    }
}

if (typeof registerShortcut === "function") {
    registerShortcut("ConjunctionQuickSearch", "Conjunction Quick Search", "Meta+Space", function () {
        callDBus("org.conjunction.Shell", "/org/conjunction/Settings", "org.conjunction.Settings", "toggleSpotlight");
    });
    registerShortcut("ConjunctionMissionControl", "Conjunction Mission Control", "Ctrl+Up", function () {
        callDBus("org.conjunction.Shell", "/org/conjunction/Settings", "org.conjunction.Settings", "toggleOverview");
    });
    registerShortcut("ConjunctionSpaceLeft", "Switch Space Left", "Ctrl+Left", function () {
        if (workspace.desktops && workspace.currentDesktop) {
            var idx = workspace.desktops.indexOf(workspace.currentDesktop);
            if (idx > 0) workspace.currentDesktop = workspace.desktops[idx - 1];
        }
    });
    registerShortcut("ConjunctionSpaceRight", "Switch Space Right", "Ctrl+Right", function () {
        if (workspace.desktops && workspace.currentDesktop) {
            var idx = workspace.desktops.indexOf(workspace.currentDesktop);
            if (idx >= 0 && idx + 1 < workspace.desktops.length) workspace.currentDesktop = workspace.desktops[idx + 1];
        }
    });
}
