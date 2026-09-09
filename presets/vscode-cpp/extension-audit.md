# Extension audit

The default profile had 27 installed extensions. Four are retained and 23 are
disabled through `extensions.allowed` in Code/User/settings.json. Nothing was
uninstalled. Built-in VS Code language support, Git and terminal remain available.

This setting is application-wide, including the STM32 profile. This is a strict
minimal setup as requested: optional tools are disabled even when they do not
conflict. To restore an extension, change its explicit entry to true or remove
that entry (`"*": true` allows unspecified extensions). Its dependencies may also
need restoring. Reload VS Code after changes. A blocked extension may show as
“not allowed” instead of a normal manually disabled extension.

New, unspecified extensions are still allowed. Explicit blocks also cover CMake
Tools, C++ DevTools and both Copilot IDs to keep the requested workflow consistent.

| Retained | Purpose |
| --- | --- |
| llvm-vs-code-extensions.vscode-clangd | C/C++ language server, clang-format and live clang-tidy |
| vadimcn.vscode-lldb | Graphical C++ debugging |
| openai.chatgpt | Official Codex chat and prompted edits |
| kylinideteam.cmake-intellisence | CMake language support and highlighting |

“CMake LLM” was interpreted as language-server/IntelliSense support. The CMake
extension is not an AI model. Its installed manifest has no build/configure
commands or task providers. Its CMake Tools snapshot bridge is explicitly disabled
with `cmakeIntelliSense.enableCMakeToolsIntegration: false`. Format-on-save is off
for CMake; manual formatting remains available. It may invoke CMake to retrieve
language help/completion metadata; that is separate from configuring/building a
project. CMake configuration and builds stay in the terminal.

| Disabled extension | Audit finding |
| --- | --- |
| chadalen.vscode-jetbrains-icon-theme | Optional icon theme; not required by the selected Light 2026 theme. |
| clemenspeters.format-json | Redundant: VS Code already supplies JSON formatting. |
| continue.continue | Additional AI provider/UI; official Codex-only workflow requested. |
| dtoplak.vscode-glsllint | Optional shader linting; depends on slevesque.shader. |
| eamodio.gitlens | Optional Git UI; built-in Git remains available. |
| mcu-debug.debug-tracker-vscode | Support dependency for optional memory/debug tools. |
| mcu-debug.memory-view | Optional specialized memory viewer. |
| ms-python.debugpy | Python debugger; outside the minimal C++ setup. |
| ms-python.python | Python integration; outside the minimal C++ setup. |
| ms-python.vscode-pylance | Python semantic language support; outside this setup. |
| ms-python.vscode-python-envs | Python environment manager; outside this setup. |
| ms-vscode.cpptools | Overlapping C++ language/debug tooling; clangd and CodeLLDB cover the selected workflow. |
| ms-vscode.cpptools-extension-pack | Bundle recommends extra C++ tooling including CMake Tools. |
| ms-vscode.cpptools-themes | Optional themes; current Light 2026 theme does not require it. |
| ms-vscode.hexeditor | Optional binary/hex editor. |
| njqdev.vscode-python-typehint | Additional Python hint features; outside this setup. |
| oderwat.indent-rainbow | Optional indentation coloring. |
| redhat.vscode-xml | Optional XML language server. |
| redhat.vscode-yaml | Optional YAML language server; YAML semantic support is lost while disabled. |
| repreng.csv | Optional CSV viewer/editor. |
| slevesque.shader | Optional shader syntax highlighting; GLSL colors are lost while disabled. |
| streetsidesoftware.code-spell-checker | Optional spell checking. |
| xaver.clang-format | Redundant for C/C++: clangd now handles formatting. |

Removed the notebook formatter pointing at disabled xaver.clang-format and the
YAML formatter pointing at disabled Red Hat YAML. Existing preferences for
optional tools are otherwise preserved for easy restoration.

Validation: installed manifests and extension dependencies inspected; setting
names checked against installed VS Code/extension schemas; JSON and retained
extension dependency closure checked. A window reload is needed to finish stopping
extensions already running. No engine source/build changes were made.

Sources:
- [CMake IntelliSense features](https://marketplace.visualstudio.com/items?itemName=KylinIdeTeam.cmake-intellisence)
- [VS Code extensions.allowed behavior](https://code.visualstudio.com/docs/enterprise/extensions)
