# roc-database-url

A database URL parser for Roc, built on [roc-url](https://github.com/niclas-ahden/roc-url).

See the documentation at [https://niclas-ahden.github.io/roc-database-url/](https://niclas-ahden.github.io/roc-database-url/).

## Usage

### Strict parsing

Use `parse` for strict validation. For PostgreSQL and MySQL it requires host,
port, user, and database, and a missing one is an error naming exactly what was
missing. Other protocols come back with labeled fields, but not requirements, since
we can't know what they require (e.g. `redis://localhost:6379` is a fine Redis URL).

```roc
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.22.1/DobkAk7zNyqAgqh2Riaj5c5DtWtKhd5iVYE5RFa6izcd.tar.zst",
    db: "https://github.com/niclas-ahden/roc-database-url/releases/download/0.3.0/HTtdy7BMLHRmLiMfdTQbf4YYzDGi6ihuUibMVUx67n8d.tar.zst",
}

import db.DatabaseUrl

main! = |_| {
    match DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb") {
        Ok(PostgreSQL(config)) => {
            # config: { protocol : Str, host : Str, port : U16, user : Str, auth, database : Str, options }
            # auth is Password(Str) or NoPassword
            # options is Dict(Str, Str)
        }

        Ok(MySQL(config)) => {} # Same structure as PostgreSQL
        Ok(SQLite(config)) => {} # config: { path : Str, options }
        Ok(Other(config)) => {} # Labelled fields, exactly what parse_partial gives

        Err(MissingPort) => {} # ...
        Err(MissingUser) => {} # ...
        Err(MissingDatabase) => {} # ...
        Err(err) => {} # Handle other errors
    }

    Ok({})
}
```

`protocol` is kept exactly as it was written, so `postgres://` and
`postgresql://` stay apart. An IPv6 host loses the brackets, so `[::1]` is
returned as `::1`.

### Lenient parsing

Use `parse_partial` when fields may be missing. Each optional field comes back
labelled as present or absent, and no defaults are assumed:

```roc
import db.DatabaseUrl

match DatabaseUrl.parse_partial("postgresql://localhost") {
    Ok(PostgreSQL(config)) | Ok(MySQL(config)) | Ok(Other(config)) => {
        # config.host is Host("localhost")
        # config.port is NoPort
        # config.user is NoUser
        # config.database is NoDatabase
        port =
            match config.port {
                Port(p) => p
                NoPort => 5432
            }
    }

    Ok(SQLite(config)) => {} # config: { path : Str, options }
    Err(err) => {} # Nonsense such as an unparseable port is still an error
}
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

### Other protocols

Any other protocol is parsed as `Other` with the protocol name kept and every
optional field labelled, whether you use `parse` or `parse_partial`:

```
mongodb://user:pass@host:port/database
redis://host:port
```
