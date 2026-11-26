// Conjunction Plasma Desktop Layout hook: defers top bar, dock, and overlays to conj-shelld
var allPanels = panels();
for (var i = 0; i < allPanels.length; ++i) {
    allPanels[i].remove();
}

var allDesktops = desktops();
for (var j = 0; j < allDesktops.length; ++j) {
    var d = allDesktops[j];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "/usr/share/wallpapers/Conjunction/conjunction-light.svg");
}
