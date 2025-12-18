app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
    dburl: "../package/main.roc",
}

import cli.Stdout
import dburl.DatabaseUrl

main! = |_|
    _ = Stdout.line! "=== Demonstrating parse_partial (lenient parsing) ==="
    _ = Stdout.line! ""

    examples = [
        # Minimal URLs (would fail with strict parse)
        "postgresql://localhost",
        "postgresql://localhost:5432",
        "mysql://localhost",
        # With just user
        "postgresql://user@localhost",
        # With user and database
        "postgresql://user@localhost/mydb",
        # Complete URL (works with both parse and parse_partial)
        "postgresql://user:pass@localhost:5432/mydb",
        # MySQL examples
        "mysql://localhost/testdb",
        "mysql://user@db.example.com",
    ]

    List.walk!(examples, {}, \{}, url ->
        _ = Stdout.line! "\n=== Parsing: $(url) ==="

        when DatabaseUrl.parse_partial(url) is
            Ok(PostgreSQL(config)) ->
                _ = Stdout.line! "  Protocol: PostgreSQL"
                host_str =
                    when config.host is
                        Just(h) -> "Just $(h)"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  Host: $(host_str)"
                port_str =
                    when config.port is
                        Just(p) -> "Just $(Num.to_str(p))"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  Port: $(port_str)"
                user_str =
                    when config.user is
                        Just(u) -> "Just $(u)"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  User: $(user_str)"
                auth_str =
                    when config.auth is
                        None -> "None"
                        Password(pass) -> "Password: $(pass)"
                _ = Stdout.line! "  Auth: $(auth_str)"
                db_str =
                    when config.database is
                        Just(db) -> "Just $(db)"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  Database: $(db_str)"
                {}

            Ok(MySQL(config)) ->
                _ = Stdout.line! "  Protocol: MySQL"
                host_str =
                    when config.host is
                        Just(h) -> "Just $(h)"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  Host: $(host_str)"
                port_str =
                    when config.port is
                        Just(p) -> "Just $(Num.to_str(p))"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  Port: $(port_str)"
                user_str =
                    when config.user is
                        Just(u) -> "Just $(u)"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  User: $(user_str)"
                auth_str =
                    when config.auth is
                        None -> "None"
                        Password(pass) -> "Password: $(pass)"
                _ = Stdout.line! "  Auth: $(auth_str)"
                db_str =
                    when config.database is
                        Just(db) -> "Just $(db)"
                        Nothing -> "Nothing"
                _ = Stdout.line! "  Database: $(db_str)"
                {}

            Ok(_) ->
                _ = Stdout.line! "  Error: Unexpected database type"
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

    _ = Stdout.line! ""
    _ = Stdout.line! "=== Comparing parse vs parse_partial ==="
    _ = Stdout.line! ""

    test_url = "postgresql://localhost"
    _ = Stdout.line! "URL: $(test_url)"
    _ = Stdout.line! ""

    _ = Stdout.line! "Using parse (strict):"
    _ =
        when DatabaseUrl.parse(test_url) is
            Ok(_) -> Stdout.line! "  Success"
            Err(MissingUser) -> Stdout.line! "  Error: MissingUser"
            Err(MissingPort) -> Stdout.line! "  Error: MissingPort (expected)"
            Err(_) -> Stdout.line! "  Error: Other error"

    _ = Stdout.line! ""
    _ = Stdout.line! "Using parse_partial (lenient):"
    when DatabaseUrl.parse_partial(test_url) is
        Ok(PostgreSQL(config)) ->
            user_str =
                when config.user is
                    Just(u) -> "Just $(u)"
                    Nothing -> "Nothing"
            Stdout.line! "  Success - user is $(user_str)"

        Ok(_) -> Stdout.line! "  Success - other type"
        Err(_) -> Stdout.line! "  Error"
