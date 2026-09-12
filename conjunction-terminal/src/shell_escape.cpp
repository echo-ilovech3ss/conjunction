#include "shell_escape.h"

namespace Conjunction {

QString escapeShellArg(const QString &arg)
{
    if (arg.isEmpty()) {
        return QStringLiteral("''");
    }

    // Check if argument contains strictly safe characters and does not begin with '-' or '+'
    bool isSafe = true;
    if (arg.at(0) == QLatin1Char('-') || arg.at(0) == QLatin1Char('+')) {
        isSafe = false;
    } else {
        for (const QChar &ch : arg) {
            ushort u = ch.unicode();
            bool alphanumeric = (u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9');
            bool safePunct = (u == '_' || u == '-' || u == '.' || u == '/' || u == ':' || u == '@' || u == '%');
            if (!alphanumeric && !safePunct) {
                isSafe = false;
                break;
            }
        }
    }

    if (isSafe) {
        return arg;
    }

    // Wrap in single quotes and replace each single quote with '\''
    QString escaped = arg;
    escaped.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
    return QLatin1Char('\'') + escaped + QLatin1Char('\'');
}

QString escapeDroppedPaths(const QStringList &paths)
{
    if (paths.isEmpty()) {
        return QString();
    }

    QStringList escapedList;
    escapedList.reserve(paths.size());
    for (const QString &path : paths) {
        if (!path.isEmpty()) {
            escapedList.append(escapeShellArg(path));
        }
    }

    return escapedList.join(QLatin1Char(' '));
}

} // namespace Conjunction
