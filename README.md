# roc-database-url

A database URL parser for Roc.

See the documentation at [https://niclas-ahden.github.io/roc-database-url/](https://niclas-ahden.github.io/roc-database-url/).

## Installation

Add to your app header:

```roc
app [main!] {
    database_url: "https://github.com/niclas-ahden/roc-database-url/releases/download/v0.1.0/<HASH>.tar.br",
}
```

## Usage

### Strict parsing

Use `parse` for strict validation. Requires host, port, user, and database:

```roc
import database_url.DatabaseUrl

when DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb") is
    Ok(PostgreSQL(config)) ->
        # config: { host, port, user, auth, database, options }
        Pg.connect!(config)

    Ok(MySQL(config)) ->
        # Same structure as PostgreSQL

    Ok(SQLite(config)) ->
        # config: { path, options }

    Ok(Other(config)) ->
        # config: { protocol, host, port, user, auth, database, options }

    Err(MissingPort) -> # ...
    Err(MissingUser) -> # ...
    Err(MissingDatabase) -> # ...
    Err(err) -> # Handle other errors
```

### Partial parsing

Use `parse_partial` when fields may be missing. Returns [`Maybe`](https://github.com/niclas-ahden/roc-maybe) types for optional fields:

```roc
import database_url.DatabaseUrl

when DatabaseUrl.parse_partial("postgresql://localhost") is
    Ok(PostgreSQL(config)) ->
        # config.host : Maybe Str
        # config.port : Maybe U16
        # config.user : Maybe Str
        # config.database : Maybe Str
        host = Maybe.with_default(config.host, "localhost")
        port = Maybe.with_default(config.port, 5432)

    Err(err) ->
        # Still validates URI format
```

## Supported formats

### PostgreSQL

```
postgresql://user:pass@host:port/database?options
postgres://user:pass@host:port/database?options
```

### MySQL

```
mysql://user:pass@host:port/database?options
```

### SQLite

```
sqlite:///absolute/path/to/db.sqlite?options
sqlite://./relative/path/to/db.sqlite
sqlite::memory:
```

### Other Protocols

Any other protocol is parsed as `Other` with the protocol name preserved:

```
mongodb://user:pass@host:port/database
redis://user:pass@host:port/database
```

## Status

`roc-database-url` is using the (old) Rust version of the Roc compiler. It'll be rewritten to use the Zig version in the future.

## Documentation

See the documentation at [https://niclas-ahden.github.io/roc-database-url/](https://niclas-ahden.github.io/roc-database-url/).

### Generating documentation locally

```bash
./docs.sh 0.1.0
```

This will generate HTML documentation and place it in `www/0.1.0/`.
