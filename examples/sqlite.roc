app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
    dburl: "../package/main.roc",
}

import cli.Stdout
import dburl.DatabaseUrl

main! = |_|
    examples = [
        # In-memory database
        "sqlite::memory:",
        # Absolute path (Unix-style)
        "sqlite:///absolute/path/to/database.db",
        # Relative path with ./ prefix
        "sqlite://./relative/path/to/database.db",
        # Simple filename
        "sqlite:mydb.sqlite",
        # With query parameters (SQLite options)
        "sqlite:///path/to/db.sqlite?mode=ro",
        # With multiple options
        "sqlite:///path/to/db.sqlite?mode=rw&cache=shared",
        # Journal mode option
        "sqlite:///path/to/db.sqlite?_journal_mode=WAL",
        # Foreign keys option
        "sqlite:///path/to/db.sqlite?_foreign_keys=on",
    ]

    List.walk!(examples, {}, \{}, url ->
        _ = Stdout.line! "\n=== Parsing: $(url) ==="

        when DatabaseUrl.parse(url) is
            Ok(SQLite(config)) ->
                _ = Stdout.line! "  Protocol: SQLite"
                _ = Stdout.line! "  Path: $(config.path)"
                if Dict.is_empty(config.options) then
                    _ = Stdout.line! "  Options: (none)"
                    {}
                else
                    options_list = config.options |> Dict.to_list
                    _ = List.walk!(options_list, {}, \{}, (key, value) ->
                        _ = Stdout.line! "  Option: $(key) = $(value)"
                        {})
                    {}

            Ok(_) ->
                _ = Stdout.line! "  Error: Expected SQLite URL"
                {}

            Err(InvalidUri) ->
                _ = Stdout.line! "  Error: Invalid URI"
                {}

            Err(InvalidPort(port)) ->
                _ = Stdout.line! "  Error: Invalid port: $(port)"
                {}

            Err(InvalidHost(host)) ->
                _ = Stdout.line! "  Error: Invalid host: $(host)"
                {}

            Err(MissingDatabase) ->
                _ = Stdout.line! "  Error: Missing database"
                {}

            Err(MissingUser) ->
                _ = Stdout.line! "  Error: Missing user"
                {}

            Err(MissingPort) ->
                _ = Stdout.line! "  Error: Missing port"
                {}

            Err(RelativeUrl) ->
                _ = Stdout.line! "  Error: Relative URL not supported"
                {}

            Err(MissingProtocol) ->
                _ = Stdout.line! "  Error: Missing protocol"
                {})

    _ = Stdout.line! "\n=== SQLite Specific Options ==="
    _ = Stdout.line! "Common SQLite URL query parameters:"
    _ = Stdout.line! "  - mode: Access mode (ro=readonly, rw=readwrite, rwc=readwrite+create, memory)"
    _ = Stdout.line! "  - cache: Cache mode (shared, private)"
    _ = Stdout.line! "  - _journal_mode: Journal mode (DELETE, TRUNCATE, PERSIST, MEMORY, WAL, OFF)"
    _ = Stdout.line! "  - _foreign_keys: Enable foreign key constraints (on/off)"
    _ = Stdout.line! "  - _synchronous: Synchronous mode (OFF, NORMAL, FULL, EXTRA)"
    _ = Stdout.line! "  - _busy_timeout: Busy timeout in milliseconds"
    _ = Stdout.line! "\nNote: SQLite URLs don't have host, port, user, or password fields."
    Stdout.line! "The database location is specified as a file path."
