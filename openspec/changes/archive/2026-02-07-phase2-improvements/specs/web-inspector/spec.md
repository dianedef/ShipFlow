## ADDED Requirements

### Requirement: Toggle web inspector function
The system SHALL provide a `toggle_web_inspector(project_dir)` function in lib.sh that enables or disables the web inspector for a given project. The toggle state SHALL be determined by the presence of `public/shipflow-inspector.js` in the project directory.

#### Scenario: Enable web inspector (not currently injected)
- **WHEN** `toggle_web_inspector "/root/myapp"` is called and `public/shipflow-inspector.js` does not exist
- **THEN** the function calls `init_web_inspector` to inject the inspector and outputs "Web inspector enabled"

#### Scenario: Disable web inspector (currently injected)
- **WHEN** `toggle_web_inspector "/root/myapp"` is called and `public/shipflow-inspector.js` exists
- **THEN** the function removes `public/shipflow-inspector.js`, removes all lines containing "shipflow-inspector" from HTML and layout files (index.html, Astro layouts, Next.js layouts), and outputs "Web inspector disabled"

#### Scenario: Invalid project directory
- **WHEN** `toggle_web_inspector "/nonexistent"` is called
- **THEN** the function returns exit code 1

### Requirement: Clean removal of injected script tags
When disabling the web inspector, the system SHALL remove both the marker comment (`<!-- shipflow-inspector -->`) and the script tag (`<script src="/shipflow-inspector.js" defer></script>`) from all files where they were injected: `index.html`, Astro layout files (`src/layouts/*.astro`), and Next.js layout files (`app/layout.tsx`, `src/app/layout.tsx`, etc.).

#### Scenario: Remove from index.html
- **WHEN** web inspector is disabled and `index.html` contains the shipflow-inspector marker and script tag
- **THEN** both lines are removed and the file is otherwise unchanged

#### Scenario: Remove from Astro layouts
- **WHEN** web inspector is disabled and `src/layouts/Layout.astro` contains the injected lines
- **THEN** the injected lines are removed from the layout file

### Requirement: Menu integration for toggle
The "More Options > Toggle Web Inspector" menu item SHALL call `toggle_web_inspector()` followed by `env_restart()` to apply the change. The menu SHALL display whether the inspector was enabled or disabled.

#### Scenario: Toggle from menu
- **WHEN** user selects "Toggle Web Inspector" from the advanced menu and selects an environment
- **THEN** the system calls `toggle_web_inspector` on the project directory, displays the result ("enabled" or "disabled"), and restarts the environment
