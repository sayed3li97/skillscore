# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Report privately via
[GitHub private vulnerability reporting](https://github.com/sayed3li97/skillscore/security/advisories/new)
or email **alkamelsayedali@gmail.com** with a description, reproduction
steps, and the affected version. You can expect an acknowledgement within
7 days.

## Scope notes

skillscore runs entirely offline and never executes the skills it analyzes
— it reads files only. Path traversal during discovery (e.g. via symlinks)
is in scope; the walker deliberately never follows symlinked directories.
