## ADDED Requirements

### Requirement: Secrets file storage
The system SHALL store credentials in a file at `$SHIPFLOW_SECRETS_DIR/secrets` (defaulting to `~/.shipflow/secrets`). The secrets directory SHALL be created with permissions 700 and the secrets file SHALL be created with permissions 600.

#### Scenario: First credential save on fresh system
- **WHEN** `save_secret()` is called and neither the directory nor file exist
- **THEN** the system creates `~/.shipflow/` with chmod 700, creates `secrets` with chmod 600, and writes the key=value pair

#### Scenario: Secrets file permissions are verified
- **WHEN** the secrets file already exists
- **THEN** `save_secret()` SHALL verify and correct permissions to 600 before writing

### Requirement: Save secret function
The system SHALL provide a `save_secret(key, value)` function that writes or updates a key=value pair in the secrets file. If the key already exists, its value SHALL be replaced. The value SHALL NOT be logged or echoed.

#### Scenario: Save new credential
- **WHEN** `save_secret "DUCKDNS_TOKEN" "abc123"` is called and the key does not exist
- **THEN** the line `DUCKDNS_TOKEN=abc123` is appended to the secrets file

#### Scenario: Update existing credential
- **WHEN** `save_secret "DUCKDNS_TOKEN" "newvalue"` is called and the key already exists
- **THEN** the existing line is replaced with `DUCKDNS_TOKEN=newvalue`

### Requirement: Load secret function
The system SHALL provide a `load_secret(key)` function that reads a value from the secrets file and outputs it to stdout. It SHALL return exit code 1 if the key is not found or the file does not exist.

#### Scenario: Load existing credential
- **WHEN** `load_secret "DUCKDNS_SUBDOMAIN"` is called and the key exists in the secrets file
- **THEN** the value is written to stdout with exit code 0

#### Scenario: Load non-existent credential
- **WHEN** `load_secret "MISSING_KEY"` is called and the key does not exist
- **THEN** nothing is written to stdout and exit code is 1

### Requirement: DuckDNS credential caching in publish flow
The "Publish to Web" menu flow SHALL attempt to load cached DuckDNS subdomain and token before prompting the user. If cached values exist, the system SHALL show the cached subdomain (not the token) and ask whether to use them. The user SHALL be able to override cached values by declining.

#### Scenario: Cached credentials found and accepted
- **WHEN** user selects "Publish to Web" and cached DUCKDNS_SUBDOMAIN and DUCKDNS_TOKEN exist
- **THEN** the system shows "Cached subdomain: <value>. Use cached credentials? (Y/n)" and proceeds with cached values on confirmation

#### Scenario: Cached credentials found but declined
- **WHEN** user declines cached credentials
- **THEN** the system prompts for new subdomain and token, and saves the new values to the secrets file

#### Scenario: No cached credentials
- **WHEN** no cached credentials exist
- **THEN** the system prompts for subdomain and token as before, then saves them to the secrets file

### Requirement: Config setting for secrets directory
The system SHALL add `SHIPFLOW_SECRETS_DIR` to `config.sh`, defaulting to `$HOME/.shipflow`.

#### Scenario: Custom secrets directory
- **WHEN** `SHIPFLOW_SECRETS_DIR` is set to a custom path before sourcing config.sh
- **THEN** the secrets file is read from and written to `$SHIPFLOW_SECRETS_DIR/secrets`
