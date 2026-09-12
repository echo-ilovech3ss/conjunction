#pragma once

#include <QString>
#include <QStringList>

namespace Conjunction {

// Safely escape an argument for POSIX shells (bash, zsh, dash, fish).
// Wraps in single quotes with internal single quotes escaped via '\''.
// Special characters, leading dashes, whitespace, and semicolons are fully neutralized.
QString escapeShellArg(const QString &arg);

// Safely escape a list of file paths into a space-separated string.
// Never appends a newline or Enter character.
QString escapeDroppedPaths(const QStringList &paths);

} // namespace Conjunction
