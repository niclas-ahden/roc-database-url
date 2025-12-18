module [
    DatabaseUrl,
    PartialDatabaseUrl,
    ParseError,
    parse,
    parse_partial,
]

import url.Uri
import url.Url
import maybe.Maybe exposing [Maybe]

## Convert a string to Maybe, returning Nothing if empty
from_non_empty_str : Str -> Maybe Str
from_non_empty_str = |str|
    if Str.is_empty(str) then
        Nothing
    else
        Just(str)

## Check if string starts with prefix (case-insensitive ASCII)
starts_with_caseless : Str, Str -> Bool
starts_with_caseless = |str, prefix|
    prefix_len = Str.count_utf8_bytes(prefix)
    str_bytes = Str.to_utf8(str)
    str_prefix_bytes = List.take_first(str_bytes, prefix_len)
    when Str.from_utf8(str_prefix_bytes) is
        Ok(str_prefix) -> Str.caseless_ascii_equals(str_prefix, prefix)
        Err(_) -> Bool.false

## Drop first n bytes from a string
drop_first_bytes : Str, U64 -> Str
drop_first_bytes = |str, n|
    str
    |> Str.to_utf8
    |> List.drop_first(n)
    |> Str.from_utf8
    |> Result.with_default("")

## Represents a parsed database URL with protocol-specific configuration.
## All fields are required (strict parsing).
DatabaseUrl : [
    PostgreSQL {
            host : Str,
            port : U16,
            user : Str,
            auth : [None, Password Str],
            database : Str,
            options : Dict Str Str,
        },
    MySQL {
            host : Str,
            port : U16,
            user : Str,
            auth : [None, Password Str],
            database : Str,
            options : Dict Str Str,
        },
    SQLite {
            path : Str,
            options : Dict Str Str,
        },
    Other {
            protocol : Str,
            host : Str,
            port : U16,
            user : Str,
            auth : [None, Password Str],
            database : Str,
            options : Dict Str Str,
        },
]

## Represents a partially parsed database URL where most fields are optional.
## Useful when you want to parse incomplete URLs without errors.
PartialDatabaseUrl : [
    PostgreSQL {
            host : Maybe Str,
            port : Maybe U16,
            user : Maybe Str,
            auth : [None, Password Str],
            database : Maybe Str,
            options : Dict Str Str,
        },
    MySQL {
            host : Maybe Str,
            port : Maybe U16,
            user : Maybe Str,
            auth : [None, Password Str],
            database : Maybe Str,
            options : Dict Str Str,
        },
    SQLite {
            path : Str,
            options : Dict Str Str,
        },
    Other {
            protocol : Str,
            host : Maybe Str,
            port : Maybe U16,
            user : Maybe Str,
            auth : [None, Password Str],
            database : Maybe Str,
            options : Dict Str Str,
        },
]

## Errors that can occur when parsing a database URL
ParseError : [
    InvalidHost Str,
    InvalidPort Str,
    InvalidUri,
    MissingDatabase,
    MissingPort,
    MissingProtocol,
    MissingUser,
    RelativeUrl,
]

## Parse a database URL string into a DatabaseUrl
##
## Supports PostgreSQL, MySQL, SQLite, and other database URL formats:
## - PostgreSQL: `postgresql://user:pass@host:port/database?options`
## - MySQL: `mysql://user:pass@host:port/database?options`
## - SQLite: `sqlite:///path/to/db.sqlite?options`
## - Other: `protocol://user:pass@host:port/database?options` (e.g., mongodb, redis)
##
## Example:
## ```
## url = DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb?sslmode=require")
## when url is
##     Ok(PostgreSQL(config)) -> # Use config with e.g. roc-pg
##     Err(InvalidUri) -> # Handle error
## ```
parse : Str -> Result DatabaseUrl ParseError
parse = |url_str|
    # Handle SQLite URLs specially since they don't follow standard URL format
    if starts_with_caseless(url_str, "sqlite:") then
        parse_sqlite_database(url_str)
        |> Result.map_ok(SQLite)
    else
        parsed_uri =
            Uri.parse_uri(url_str)
            |> Result.map_err(
                |err|
                    when err is
                        InvalidUri -> InvalidUri
                        InvalidPort(str) -> InvalidPort(str)
                        InvalidHost(str) -> InvalidHost(str),
            )

        parsed_uri
        |> Result.try(
            |uri|
                when uri is
                    Relative(_) -> Err(RelativeUrl)
                    Absolute(parts) ->
                        when parts.protocol is
                            Just(protocol) ->
                                if Str.caseless_ascii_equals(protocol, "postgresql") or Str.caseless_ascii_equals(protocol, "postgres") then
                                    parse_server_database(parts)
                                    |> Result.map_ok(PostgreSQL)
                                else if Str.caseless_ascii_equals(protocol, "mysql") then
                                    parse_server_database(parts)
                                    |> Result.map_ok(MySQL)
                                else
                                    parse_other(protocol, parts)

                            Nothing -> Err(MissingProtocol),
        )

## Parse a database URL string into a PartialDatabaseUrl
##
## Unlike `parse`, this function accepts incomplete URLs and returns `Maybe` for optional fields.
## Useful when you want to parse URLs that may be missing host, port, user, or database.
## No default values are assumed - missing fields are returned as `Nothing`.
##
## Supports PostgreSQL, MySQL, SQLite, and other database URL formats:
## - PostgreSQL: `postgresql://[user[:pass]@][host][:port][/database][?options]`
## - MySQL: `mysql://[user[:pass]@][host][:port][/database][?options]`
## - SQLite: `sqlite:///path/to/db.sqlite?options`
## - Other: `protocol://[user[:pass]@][host][:port][/database][?options]` (e.g., mongodb, redis)
##
## Example:
## ```
## url = DatabaseUrl.parse_partial("postgresql://localhost")
## when url is
##     Ok(PostgreSQL(config)) ->
##         # config.host is Just "localhost"
##         # config.user is Nothing
##         # config.port is Nothing
##         port = Maybe.with_default(config.port, 5432)
##     Err(InvalidUri) -> # Handle error
## ```
parse_partial : Str -> Result PartialDatabaseUrl ParseError
parse_partial = |url_str|
    # Handle SQLite URLs specially since they don't follow standard URL format
    if starts_with_caseless(url_str, "sqlite:") then
        parse_sqlite_database(url_str)
        |> Result.map_ok(SQLite)
    else
        parsed_uri =
            Uri.parse_uri(url_str)
            |> Result.map_err(
                |err|
                    when err is
                        InvalidUri -> InvalidUri
                        InvalidPort(str) -> InvalidPort(str)
                        InvalidHost(str) -> InvalidHost(str),
            )

        parsed_uri
        |> Result.try(
            |uri|
                when uri is
                    Relative(_) -> Err(RelativeUrl)
                    Absolute(parts) ->
                        when parts.protocol is
                            Just(protocol) ->
                                if Str.caseless_ascii_equals(protocol, "postgresql") or Str.caseless_ascii_equals(protocol, "postgres") then
                                    parse_server_database_partial(parts)
                                    |> Result.map_ok(PostgreSQL)
                                else if Str.caseless_ascii_equals(protocol, "mysql") then
                                    parse_server_database_partial(parts)
                                    |> Result.map_ok(MySQL)
                                else
                                    parse_other_partial(protocol, parts)

                            Nothing -> Err(MissingProtocol),
        )

## Generic parser for server-based databases (PostgreSQL, MySQL, Other)
## Extracts and validates common fields, returning a config record
parse_server_database : { protocol : Maybe Str, userinfo : Maybe Str, host : Str, port : Maybe U16, path : Str, query : Maybe Str, fragment : Maybe Str } -> Result { host : Str, port : U16, user : Str, auth : [None, Password Str], database : Str, options : Dict Str Str } ParseError
parse_server_database = |parts|
    # Extract port (required for strict parsing)
    port =
        when parts.port is
            Just(p) -> Ok(p)
            Nothing -> Err(MissingPort)

    # Parse userinfo into user and password (required for strict parsing)
    user_auth_result =
        when parts.userinfo is
            Nothing -> Err(MissingUser)
            Just(userinfo) ->
                when Str.split_first(userinfo, ":") is
                    Ok({ before, after }) ->
                        decoded_user = percent_decode(before)
                        decoded_pass = percent_decode(after)
                        Ok((decoded_user, Password(decoded_pass)))

                    Err(NotFound) ->
                        Ok((percent_decode(userinfo), None))

    # Extract database from path (required for strict parsing)
    database =
        raw_db =
            if Str.starts_with(parts.path, "/") then
                parts.path
                |> Str.replace_first("/", "")
                |> percent_decode
            else
                percent_decode(parts.path)
        if Str.is_empty(raw_db) then
            Err(MissingDatabase)
        else
            Ok(raw_db)

    # Parse query parameters into options
    options =
        parts.query
        |> Maybe.map(parse_query_params)
        |> Maybe.with_default(Dict.empty({}))

    # Validate required fields
    port
    |> Result.try(
        |valid_port|
            user_auth_result
            |> Result.try(
                |(user, auth)|
                    database
                    |> Result.map_ok(
                        |valid_database| {
                            host: parts.host,
                            port: valid_port,
                            user,
                            auth,
                            database: valid_database,
                            options,
                        },
                    ),
            ),
    )

## Parse URL with other protocol (e.g., mongodb, redis, etc.)
parse_other : Str, { protocol : Maybe Str, userinfo : Maybe Str, host : Str, port : Maybe U16, path : Str, query : Maybe Str, fragment : Maybe Str } -> Result DatabaseUrl ParseError
parse_other = |protocol, parts|
    parse_server_database(parts)
    |> Result.map_ok(|config| Other({ protocol, host: config.host, port: config.port, user: config.user, auth: config.auth, database: config.database, options: config.options }))

## Parse SQLite URL into config record
## SQLite uses file paths, not host/port/user
parse_sqlite_database : Str -> Result { path : Str, options : Dict Str Str } ParseError
parse_sqlite_database = |url_str|
    # For SQLite, extract the file path from the original URL
    # sqlite:///absolute/path or sqlite://./relative/path or sqlite::memory:

    # Remove "sqlite://" or "sqlite:" prefix (case-insensitive)
    url_without_protocol =
        if starts_with_caseless(url_str, "sqlite://") then
            drop_first_bytes(url_str, 9)
        else if starts_with_caseless(url_str, "sqlite:") then
            drop_first_bytes(url_str, 7)
        else
            url_str

    # Split path and query string
    (path_part, query_part) =
        when Str.split_first(url_without_protocol, "?") is
            Ok({ before, after }) -> (before, Just(after))
            Err(NotFound) -> (url_without_protocol, Nothing)

    path = percent_decode(path_part)

    # Parse query parameters into options
    options =
        when query_part is
            Nothing -> Dict.empty({})
            Just(query_str) -> parse_query_params(query_str)

    Ok({ path, options })

## Generic partial parser for server-based databases
## Extracts common fields with optional values, returns a config record
parse_server_database_partial : { protocol : Maybe Str, userinfo : Maybe Str, host : Str, port : Maybe U16, path : Str, query : Maybe Str, fragment : Maybe Str } -> Result { host : Maybe Str, port : Maybe U16, user : Maybe Str, auth : [None, Password Str], database : Maybe Str, options : Dict Str Str } ParseError
parse_server_database_partial = |parts|
    # Extract host (optional for partial parsing)
    host = from_non_empty_str(parts.host)

    # Parse userinfo into user and password
    (user, auth) =
        parts.userinfo
        |> Maybe.map(
            |userinfo|
                when Str.split_first(userinfo, ":") is
                    Ok({ before, after }) ->
                        decoded_user = percent_decode(before)
                        decoded_pass = percent_decode(after)
                        (Just(decoded_user), Password(decoded_pass))

                    Err(NotFound) ->
                        (Just(percent_decode(userinfo)), None),
        )
        |> Maybe.with_default((Nothing, None))

    # Extract database from path (optional)
    database =
        if Str.starts_with(parts.path, "/") then
            parts.path
            |> Str.replace_first("/", "")
            |> percent_decode
            |> from_non_empty_str
        else
            parts.path
            |> percent_decode
            |> from_non_empty_str

    # Parse query parameters into options
    options =
        parts.query
        |> Maybe.map(parse_query_params)
        |> Maybe.with_default(Dict.empty({}))

    Ok(
        {
            host,
            port: parts.port,
            user,
            auth,
            database,
            options,
        },
    )

## Parse URL with other protocol (partial - allows missing fields)
parse_other_partial : Str, { protocol : Maybe Str, userinfo : Maybe Str, host : Str, port : Maybe U16, path : Str, query : Maybe Str, fragment : Maybe Str } -> Result PartialDatabaseUrl ParseError
parse_other_partial = |protocol, parts|
    parse_server_database_partial(parts)
    |> Result.map_ok(|config| Other({ protocol, host: config.host, port: config.port, user: config.user, auth: config.auth, database: config.database, options: config.options }))

## Parse query parameters into a Dict
parse_query_params : Str -> Dict Str Str
parse_query_params = |query_str|
    query_str
    |> Str.split_on("&")
    |> List.walk(
        Dict.empty({}),
        |dict, param|
            when Str.split_first(param, "=") is
                Ok({ before, after }) ->
                    key = percent_decode(before)
                    value = percent_decode(after)
                    Dict.insert(dict, key, value)

                Err(NotFound) ->
                    # Parameter without value (e.g., "?flag")
                    key = percent_decode(param)
                    Dict.insert(dict, key, ""),
    )

## Percent-decode a string (RFC 3986)
## Converts %XX hex codes back to characters
## Falls back to the original string if decoding fails
percent_decode : Str -> Str
percent_decode = |input|
    when Url.percent_decode(input) is
        Ok(decoded) -> decoded
        Err(_) -> input

# Tests
expect
    # Test basic PostgreSQL URL
    when parse("postgresql://user:pass@localhost:5432/mydb") is
        Ok(PostgreSQL(config)) ->
            config.host
            == "localhost"
            and config.port
            == 5432
            and config.user
            == "user"
            and config.auth
            == Password("pass")
            and config.database
            == "mydb"

        _ -> Bool.false

expect
    # Test PostgreSQL URL without port (strict parsing requires port)
    parse("postgresql://user@localhost/mydb") == Err(MissingPort)

expect
    # Test PostgreSQL URL with query parameters
    when parse("postgresql://user:pass@localhost:5432/mydb?sslmode=require&connect_timeout=10") is
        Ok(PostgreSQL(config)) ->
            when Dict.get(config.options, "sslmode") is
                Ok(v) -> v == "require"
                Err(_) -> Bool.false

        _ -> Bool.false

expect
    # Test MySQL URL
    when parse("mysql://user:pass@localhost:3306/testdb") is
        Ok(MySQL(config)) ->
            config.host
            == "localhost"
            and config.port
            == 3306
            and config.user
            == "user"
            and config.auth
            == Password("pass")
            and config.database
            == "testdb"

        _ -> Bool.false

expect
    # Test MySQL URL without port (strict parsing requires port)
    parse("mysql://user@localhost/mydb") == Err(MissingPort)

expect
    # Test SQLite URL with absolute path
    parse("sqlite:///absolute/path/to/db.sqlite")
    == Ok(SQLite({ path: "/absolute/path/to/db.sqlite", options: Dict.empty({}) }))

expect
    # Test SQLite URL with relative path
    parse("sqlite://./relative/db.sqlite")
    == Ok(SQLite({ path: "./relative/db.sqlite", options: Dict.empty({}) }))

expect
    # Test SQLite URL with memory
    parse("sqlite::memory:")
    == Ok(SQLite({ path: ":memory:", options: Dict.empty({}) }))

expect
    # Test other protocol (mongodb) - requires port for strict parsing
    parse("mongodb://localhost/mydb") == Err(MissingPort)

expect
    # Test other protocol (mongodb) with all required fields
    when parse("mongodb://user:pass@localhost:27017/mydb") is
        Ok(Other(config)) ->
            config.protocol
            == "mongodb"
            and config.host
            == "localhost"
            and config.port
            == 27017
            and config.user
            == "user"
            and config.database
            == "mydb"

        _ -> Bool.false

expect
    # Test percent-encoded password
    when parse("postgresql://user:p%40ss%21@localhost:5432/mydb") is
        Ok(PostgreSQL(config)) -> config.auth == Password("p@ss!")
        _ -> Bool.false

expect
    # Test missing database (strict parsing requires database)
    parse("postgresql://user:pass@localhost:5432") == Err(MissingDatabase)

expect
    # Test missing database with trailing slash
    parse("postgresql://user:pass@localhost:5432/") == Err(MissingDatabase)

expect
    # Test postgres:// alias for postgresql://
    when parse("postgres://user:pass@localhost:5432/mydb") is
        Ok(PostgreSQL(config)) -> config.host == "localhost" and config.database == "mydb"
        _ -> Bool.false

expect
    # Test user without password (auth = None)
    when parse("postgresql://user@localhost:5432/mydb") is
        Ok(PostgreSQL(config)) -> config.user == "user" and config.auth == None
        _ -> Bool.false

expect
    # Test missing user
    parse("postgresql://localhost:5432/mydb") == Err(MissingUser)

expect
    # Test empty host (caught by URI parser as invalid)
    parse("postgresql://user:pass@:5432/mydb") == Err(InvalidHost(""))

expect
    # Test SQLite with query options
    when parse("sqlite:///path/to/db.sqlite?mode=ro&cache=shared") is
        Ok(SQLite(config)) ->
            config.path
            == "/path/to/db.sqlite"
            and Dict.get(config.options, "mode")
            == Ok("ro")
            and Dict.get(config.options, "cache")
            == Ok("shared")

        _ -> Bool.false

# parse_partial tests
expect
    # Test parse_partial with minimal URL
    when parse_partial("postgresql://localhost") is
        Ok(PostgreSQL(config)) ->
            config.host
            == Just("localhost")
            and config.port
            == Nothing
            and config.user
            == Nothing
            and config.database
            == Nothing

        _ -> Bool.false

expect
    # Test parse_partial with port only
    when parse_partial("postgresql://localhost:5432") is
        Ok(PostgreSQL(config)) ->
            config.host
            == Just("localhost")
            and config.port
            == Just(5432)
            and config.user
            == Nothing

        _ -> Bool.false

expect
    # Test parse_partial with user
    when parse_partial("mysql://user@localhost:3306/mydb") is
        Ok(MySQL(config)) ->
            config.user
            == Just("user")
            and config.auth
            == None
            and config.database
            == Just("mydb")

        _ -> Bool.false

expect
    # Test parse_partial SQLite (same as strict)
    parse_partial("sqlite::memory:") == Ok(SQLite({ path: ":memory:", options: Dict.empty({}) }))

expect
    # Test empty password (different from no password)
    when parse("postgresql://user:@localhost:5432/mydb") is
        Ok(PostgreSQL(config)) -> config.user == "user" and config.auth == Password("")
        _ -> Bool.false

expect
    # Test SQLite with empty path (creates temporary database)
    parse("sqlite:") == Ok(SQLite({ path: "", options: Dict.empty({}) }))

expect
    # Test parse_partial with other protocol
    when parse_partial("mongodb://localhost") is
        Ok(Other(config)) ->
            config.protocol
            == "mongodb"
            and config.host
            == Just("localhost")
            and config.port
            == Nothing

        _ -> Bool.false

# Case-insensitivity tests
expect
    # Test uppercase POSTGRESQL://
    when parse("POSTGRESQL://user:pass@localhost:5432/mydb") is
        Ok(PostgreSQL(config)) -> config.host == "localhost" and config.database == "mydb"
        _ -> Bool.false

expect
    # Test mixed case PostgreSQL://
    when parse("PostgreSQL://user:pass@localhost:5432/mydb") is
        Ok(PostgreSQL(config)) -> config.host == "localhost"
        _ -> Bool.false

expect
    # Test uppercase MYSQL://
    when parse("MYSQL://user:pass@localhost:3306/mydb") is
        Ok(MySQL(config)) -> config.host == "localhost"
        _ -> Bool.false

expect
    # Test uppercase SQLITE:
    when parse("SQLITE::memory:") is
        Ok(SQLite(config)) -> config.path == ":memory:"
        _ -> Bool.false

expect
    # Test uppercase SQLITE:// with path
    when parse("SQLITE:///path/to/db.sqlite") is
        Ok(SQLite(config)) -> config.path == "/path/to/db.sqlite"
        _ -> Bool.false

# Edge case tests
expect
    # Test empty input
    parse("") == Err(InvalidUri)

expect
    # Test query param without value (?key without =)
    when parse("postgresql://user:pass@localhost:5432/mydb?sslmode") is
        Ok(PostgreSQL(config)) ->
            Dict.get(config.options, "sslmode") == Ok("")

        _ -> Bool.false

expect
    # Test query param with empty value (?key=)
    when parse("postgresql://user:pass@localhost:5432/mydb?sslmode=") is
        Ok(PostgreSQL(config)) ->
            Dict.get(config.options, "sslmode") == Ok("")

        _ -> Bool.false

