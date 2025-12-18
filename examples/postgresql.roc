app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
    dburl: "../package/main.roc",
}

import cli.Stdout
import dburl.DatabaseUrl

main! = |_|
    examples = [
        # Basic PostgreSQL URL (missing user and port - will fail strict parsing)
        "postgresql://localhost",
        # With port but no user (will fail strict parsing)
        "postgresql://localhost:5432",
        # With database but no port (will fail strict parsing)
        "postgresql://user@localhost/mydb",
        # With user and password but no port (will fail strict parsing)
        "postgresql://user:pass@localhost/mydb",
        # Full URL with all components
        "postgresql://user:pass@db.example.com:5432/production",
        # Alternative postgres:// schema
        "postgres://user:pass@localhost:5432/mydb",
        # With query parameters
        "postgresql://user:pass@localhost:5432/mydb?sslmode=require&connect_timeout=10",
        # With percent-encoded password containing special characters
        "postgresql://user:p%40ss%21@localhost:5432/mydb",
        # With percent-encoded username and password
        "postgresql://my%20user:my%2Bpass@localhost:5432/my%2Ddb",
    ]

    List.walk!(examples, {}, \{}, url ->
        _ = Stdout.line! "\n=== Parsing: $(url) ==="

        when DatabaseUrl.parse(url) is
            Ok(PostgreSQL(config)) ->
                _ = Stdout.line! "  Protocol: PostgreSQL"
                _ = Stdout.line! "  Host: $(config.host)"
                _ = Stdout.line! "  Port: $(Num.to_str(config.port))"
                _ = Stdout.line! "  User: $(config.user)"
                auth_str =
                    when config.auth is
                        None -> "None"
                        Password(pass) -> "Password: $(pass)"
                _ = Stdout.line! "  Auth: $(auth_str)"
                _ = Stdout.line! "  Database: $(config.database)"
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
                _ = Stdout.line! "  Error: Expected PostgreSQL URL"
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

    _ = Stdout.line! "\n=== Example: Using with roc-pg ==="
    _ = Stdout.line! "```"
    _ = Stdout.line! "parsed = DatabaseUrl.parse \"postgresql://user:pass@localhost:5432/mydb\""
    _ = Stdout.line! "when parsed is"
    _ = Stdout.line! "    Ok (PostgreSQL config) ->"
    _ = Stdout.line! "        # Pass config directly to roc-pg"
    _ = Stdout.line! "        # The 'options' field is ignored by roc-pg"
    _ = Stdout.line! "        connection = Pg.connect! config"
    _ = Stdout.line! "        # Use connection..."
    _ = Stdout.line! "    Err err ->"
    _ = Stdout.line! "        # Handle error"
    Stdout.line! "```"
