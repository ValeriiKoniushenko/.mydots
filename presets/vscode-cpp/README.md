# VS Code + Codex + C++ on this machine

Configured 2026-09-09 for Linux, terminal-driven CMake builds, and graphical editing/debugging.

## Capability boundary

Your requirement is **official OpenAI extension + Codex/ChatGPT login only**.
The installed Codex extension does not expose an inline-completion provider or a
Cursor-style next-edit Tab workflow. Its official documentation describes chat,
editor context, and prompted edits. This setup therefore does **not** supply AI
Tab completion. Normal C++ completion comes from clangd. For a semantic symbol
rename use F2; for a larger transformation select code and ask Codex.

Copilot and Continue completion settings are disabled. No API keys, additional
AI subscriptions, or third-party model providers are needed for this setup.

## Minimum extensions

For the latest four-extension setup including CMake language support, see
[the extension audit](extension-audit.md). It supersedes the optional-extension
activation advice below. These three provide the C++/AI foundation:

| Extension ID | Responsibility |
| --- | --- |
| `llvm-vs-code-extensions.vscode-clangd` | Index, navigation, semantic completion, formatting, live clang-tidy diagnostics |
| `vadimcn.vscode-lldb` | Graphical C++ debugger |
| `openai.chatgpt` | Official Codex chat and prompted code edits |

They are installed. For reproducing the setup:

```sh
code --install-extension llvm-vs-code-extensions.vscode-clangd
code --install-extension vadimcn.vscode-lldb
code --install-extension openai.chatgpt
```

You already had many other extensions. They were not uninstalled because they
may serve other projects. In Extensions, use **Disable (Workspace)** for Continue,
Copilot if present, the C/C++ Extension Pack, C/C++ and xaver.clang-format if you
want only these three active C++/AI tools here. Keep unrelated language tools as
needed. Microsoft C/C++ language features are already disabled in user settings.
CMake Tools is unnecessary for this workflow; decline its repository recommendation.

## Start and sign in

```sh
code /home/valerii/.config/presets/vscode-cpp/Nexium.code-workspace
```

Use the default VS Code profile: this setup modifies `Code/User/settings.json`
and `Code/User/keybindings.json`. A named profile can override them. Run
**Developer: Reload Window** if the project is already open.

Press Ctrl+Alt+C (or run **Codex: Open Codex Sidebar**) and sign in with ChatGPT
if prompted. Use your existing account's available Codex models; there is no
need to set an API key or replace the extension's bundled CLI. Account access
and interactive sign-in must be confirmed in the UI.

Drag the Codex view to the secondary sidebar if you want Explorer on the left
and chat on the right. Open related headers and source files, select the relevant
code, then press Ctrl+Shift+L to add it to the current Codex thread. Ask for an
explanation or a concrete edit and inspect its diff. Follow-ups default to steer,
matching your Cursor preference. Existing Codex configuration is preserved.

## Terminal configuration and builds

Installed tools include CMake, Ninja, GCC, Clang, clangd, clang-format,
clang-tidy and LLDB. No system package installation was needed.

The existing Nexium cache uses Ninja/GCC but has an empty build type and tests
and benchmarks disabled. To prepare the normal Debug configuration, from the
repository root run:

```sh
cd /home/valerii/workspace/Nexium
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DNEXIUM_DISABLE_TESTS=OFF -DNEXIUM_DISABLE_BENCHMARKS=OFF
cmake --build build --parallel
```

This keeps the existing compiler. For later incremental builds use only the
second command. Do not switch compilers inside an existing CMake cache.
If dependencies are missing, initialize the pinned submodules as documented in
AGENTS.md before configuring. The build also runs the project's JRM generator.

No launch configuration has a preLaunchTask, and CMake automatic configuration
and build-before-run are disabled. Build in your terminal before pressing F5.
This setup task did not rebuild or modify the engine.

## Indexing, formatting and lint

The repository's `.clangd` already points at `build/compile_commands.json`.
clangd reads the actual compiler flags and language standard from this database;
no manually maintained include-path list or forced C++23 editor setting is needed.
Background indexing and clang-tidy are enabled. The query-driver allowlist
contains only the installed system GCC/Clang driver paths, so clangd can obtain
matching standard-library include directories.

After configuring/building, open a C++ source and allow indexing to finish.
Use **View: Toggle Output**, select **clangd**, and verify that it loaded the
compilation database. Use **clangd: Restart language server** if needed after a
large toolchain/database change. If moving to another build directory, update
the repository's `.clangd` CompilationDatabase setting yourself to match it.
Search/watcher exclusions do not replace clangd's own indexing configuration.

C and C++ formatting on save now uses clangd's built-in clang-format engine,
reading `.clang-format`. Ctrl+Alt+Enter formats the document. No separate
formatting extension is necessary. The existing modificationsIfAvailable save
mode is retained; depending on formatter support it may format the entire file.

Live clang-tidy diagnostics use `.clang-tidy`, appear in Problems and support
Alt+Enter fixes when available. clangd runs only its supported subset of checks;
it does not replace the full CI lint command. For uncommitted C++ files:

```sh
python3 .gitea/check_clang_format.py --files path/to/changed.cpp --no-gitea
python3 .gitea/check_clang_tidy.py --files path/to/changed.cpp --build-dir build --fail-on error --no-gitea
```

Local LLVM tools are **22.1.8**, whereas AGENTS.md specifies **19.1.7** for CI.
Formatting and diagnostics can differ. Exact parity requires matching LLVM tools,
including clangd if using its built-in formatter. No system downgrade was made.
`clang-tidy --verify-config` also reports the existing check
`cppcoreguidelines-explicit-conversions` as unknown. That repository setting was
not changed. The lint configuration is therefore not fully clean on this machine.

## Graphical debugging

Open the supplied `.code-workspace`, build in the terminal, then choose
**Nexium: TemplateGame (CodeLLDB; terminal build)** in Run and Debug and press F5.
Set a breakpoint first. Use Variables, Watch, Call Stack, and the Debug Console.
F10 steps over, F11 steps into, Shift+F11 steps out, Shift+F5 stops.
The test launch entry starts `build/bin/Nexium_Tests`; add a GoogleTest filter to
its `args` when needed. The working directory is the repository root.

Select the entries prefixed **Nexium:**. The repository also contains an older
`cppdbg` LLDB entry pointing at `/usr/bin/lldb`; that expects an MI interface and
is not the CodeLLDB configuration provided here. Both can appear in the dropdown.
CodeLLDB uses `type: lldb`. GCC-produced debug info can also be used with LLDB.
The game's graphical/OpenGL session must be available.

## Shortcuts

| Keys | Action |
| --- | --- |
| Alt+Space | clangd completion menu (desktop window-manager binding may need releasing) |
| Tab | Accept selected normal completion; no AI completion is configured |
| F12 / Shift+F12 | Definition / references |
| F2 | Semantic rename |
| Alt+Enter | C++ quick fix |
| Ctrl+Alt+Enter | Format document |
| Ctrl+Alt+C | Open Codex |
| Ctrl+Shift+L | Add selected code to Codex thread |
| Ctrl+L / Ctrl+D | Your existing delete-line / duplicate-selection bindings |

The competing AI trigger on Alt+Space and invalid modifier-only shortcuts were
removed. Other existing keybindings and appearance preferences were preserved.

## Verification and review

- clangd parsed `sources/Foundation/Configs.cpp` using the real compilation
  database and GCC 16 headers: zero errors; header and AST indexing succeeded.
- clang-format successfully loaded the project style.
- clang-tidy configuration verification reported the unknown check noted above.
- A separate temporary Debug C++ executable hit a main breakpoint under system
  LLDB, exposed a local variable, and exited successfully. This checks system
  LLDB; the CodeLLDB extension's bundled adapter still needs the UI check above.
- Settings, keybindings and workspace JSON were parsed successfully.
- Codex is installed. Chat authentication, interactive completion/navigation,
  CodeLLDB UI debugging, and the game's runtime were not exercised here.
- `build/bin/TemplateGame` was absent during inspection; F5 requires building it.

The config repository previously ignored all of `Code/User` (and `.gitignore`
itself). Narrow exceptions now expose only settings and keybindings plus
`.gitignore`, excluding caches/authentication. These files appear as new files
because there was no tracked baseline. `setup-changes.patch` shows the exact
before/after preference edits. Backups are in `/tmp/vscode-cpp-before` for this
session. No changes were staged or committed.

## Sources

- [Official Codex IDE setup and editor-context workflow](https://learn.chatgpt.com/docs/codex/ide)
- [clangd installation and compilation databases](https://clangd.llvm.org/installation)
- [clangd configuration and clang-tidy support](https://clangd.llvm.org/config)

Codex capability conclusions also use the installed extension's manifest and
implementation inspection, not an assumption that chat implies Tab completion.
