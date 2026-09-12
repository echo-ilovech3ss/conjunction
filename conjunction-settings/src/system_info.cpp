#include "system_info.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QProcess>
#include <QSysInfo>
#include <QRegularExpression>
#ifdef Q_OS_UNIX
#include <sys/utsname.h>
#include <unistd.h>
#endif

SystemInfo::SystemInfo(QObject *parent)
    : QObject(parent)
{
    probeSystem();
}

SystemInfo::~SystemInfo() = default;

void SystemInfo::probeSystem()
{
#ifdef Q_OS_UNIX
    struct utsname u;
    if (uname(&u) == 0) {
        m_osKernel = QString("%1 %2 (%3)").arg(u.sysname, u.release, u.machine);
    }
#else
    m_osKernel = QSysInfo::kernelType() + " " + QSysInfo::kernelVersion();
#endif

    // 1. CPU Model from /proc/cpuinfo
    QFile cpuinfo("/proc/cpuinfo");
    if (cpuinfo.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&cpuinfo);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.startsWith("model name", Qt::CaseInsensitive)) {
                QStringList parts = line.split(':');
                if (parts.size() > 1) {
                    m_cpuModel = parts[1].trimmed();
                    break;
                }
            }
        }
    }

    // 2. Memory Total from /proc/meminfo
    QFile meminfo("/proc/meminfo");
    if (meminfo.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&meminfo);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.startsWith("MemTotal:", Qt::CaseInsensitive)) {
                QStringList parts = line.split(QRegularExpression("\\s+"));
                if (parts.size() > 1) {
                    qint64 kb = parts[1].toLongLong();
                    double gb = kb / (1024.0 * 1024.0);
                    m_memoryTotal = QString::asprintf("%.1f GB RAM", gb);
                    break;
                }
            }
        }
    }

    // 3. Graphics Device from /sys/class/drm
    QDir drmDir("/sys/class/drm");
    if (drmDir.exists()) {
        QStringList entries = drmDir.entryList(QStringList() << "card0-*", QDir::Dirs | QDir::NoDotAndDotDot);
        if (!entries.isEmpty()) {
            m_graphicsDevice = "Linux DRM / KMS (" + entries.first() + ")";
        }
    }

    // Check Wayland / X11 session
    QString waylandDisplay = qEnvironmentVariable("WAYLAND_DISPLAY");
    if (!waylandDisplay.isEmpty()) {
        m_desktopSession = "Conjunction Desktop (KWin Wayland: " + waylandDisplay + ")";
    } else {
        m_desktopSession = "Conjunction Desktop (KWin Wayland)";
    }
}

QString SystemInfo::osName() const { return m_osName; }
QString SystemInfo::osKernel() const { return m_osKernel; }
QString SystemInfo::cpuModel() const { return m_cpuModel; }
QString SystemInfo::memoryTotal() const { return m_memoryTotal; }
QString SystemInfo::graphicsDevice() const { return m_graphicsDevice; }
QString SystemInfo::desktopSession() const { return m_desktopSession; }
QString SystemInfo::uptime() const
{
    QFile up("/proc/uptime");
    if (up.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&up);
        double secs = 0;
        in >> secs;
        int hours = static_cast<int>(secs) / 3600;
        int mins = (static_cast<int>(secs) % 3600) / 60;
        return QString("%1 hours, %2 mins").arg(hours).arg(mins);
    }
    return "Active session";
}
