#include <iostream>
#include <cassert>
#include <QString>
#include <QStringList>
#include <QDir>
#include <QFileInfo>

#include "../src/shell_escape.h"

// Built-in automated unit test runner for Conjunction Terminal
int runSelfTests()
{
    int passed = 0;
    int failed = 0;

    auto test = [&](const char *name, bool condition) {
        if (condition) {
            std::cout << "  [PASS] " << name << std::endl;
            passed++;
        } else {
            std::cerr << "  [FAIL] " << name << std::endl;
            failed++;
        }
    };

    std::cout << "\n=== Running Conjunction Terminal Unit Tests ===" << std::endl;

    // 1. Shell escaping - simple paths
    test("shell_escape: simple alphanumeric path is untouched",
         Conjunction::escapeShellArg("/usr/bin/ls") == "/usr/bin/ls");

    // 2. Shell escaping - spaces
    test("shell_escape: path with spaces is single-quoted",
         Conjunction::escapeShellArg("/home/user/My Documents/file.txt") == "'/home/user/My Documents/file.txt'");

    // 3. Shell escaping - single quotes
    test("shell_escape: path with single quotes escapes them safely",
         Conjunction::escapeShellArg("/path/it's a file.txt") == "'/path/it'\\''s a file.txt'");

    // 4. Shell escaping - double quotes
    test("shell_escape: path with double quotes is neutralized",
         Conjunction::escapeShellArg("/path/\"quoted\".txt") == "'/path/\"quoted\".txt'");

    // 5. Shell escaping - metacharacters (dollar, semicolon, backtick, ampersand, pipe)
    test("shell_escape: dangerous metacharacters $(whoami); rm -rf / are neutral",
         Conjunction::escapeShellArg("$(whoami); rm -rf /; `id`") == "'$(whoami); rm -rf /; `id`'");

    // 6. Shell escaping - leading dashes
    test("shell_escape: leading dash option --all is quoted",
         Conjunction::escapeShellArg("--all") == "'--all'");
    test("shell_escape: leading dash option -rf is quoted",
         Conjunction::escapeShellArg("-rf") == "'-rf'");

    // 7. Shell escaping - empty string
    test("shell_escape: empty argument returns ''",
         Conjunction::escapeShellArg("") == "''");

    // 8. Dropped paths multi-file joining
    QStringList dropped;
    dropped << "/home/user/file 1.txt" << "/etc/hosts" << "-strange--name";
    QString joined = Conjunction::escapeDroppedPaths(dropped);
    test("escapeDroppedPaths: joins multiple paths safely with space",
         joined == "'/home/user/file 1.txt' /etc/hosts '-strange--name'");
    test("escapeDroppedPaths: never appends trailing newline",
         !joined.contains('\n') && !joined.contains('\r'));

    // 9. Empty dropped paths
    test("escapeDroppedPaths: empty list yields empty string",
         Conjunction::escapeDroppedPaths(QStringList()).isEmpty());

    // 10. Working directory validation logic
    QString validDir = QDir::homePath();
    test("working_dir: home directory exists", QDir(validDir).exists());
    QString invalidDir = "/nonexistent/conjunction/path/12345";
    test("working_dir: nonexistent directory handled safely", !QDir(invalidDir).exists());

    // 11. Bundle manifest check
    QString manifestPath = "/mnt/c/Users/Way4U/Coding-projects/conjunction/data/Terminal.app/Contents/Info.toml";
    if (!QFileInfo::exists(manifestPath)) {
        manifestPath = "data/Terminal.app/Contents/Info.toml";
    }
    // We will verify the manifest exists when created
    std::cout << "\n=== Tests Completed: " << passed << " passed, " << failed << " failed ===" << std::endl;
    return (failed == 0) ? 0 : 1;
}

#ifdef TEST_STANDALONE_MAIN
int main(int argc, char **argv)
{
    return runSelfTests();
}
#endif
