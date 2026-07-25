import url.Uri

## A parsed database URL, produced by strict parsing with [DatabaseUrl.parse].
## Lenient parsing with [DatabaseUrl.parse_partial] produces a
## [PartialDatabaseUrl] instead, where missing fields are labelled rather than
## errors.
##
## PostgreSQL and MySQL get their own tags and SQLite is a file path rather
## than a server. Every other protocol (mongodb, redis, and so on) is parsed as
## `Other` and carries the same labelled fields lenient parsing produces, since
## we know what PostgreSQL and MySQL need in order to connect but not what an
## arbitrary protocol needs.
DatabaseUrl := [
	PostgreSQL(Config),
	MySQL(Config),
	SQLite(SQLiteConfig),
	Other(PartialConfig),
].{

	## Structural equality, derived: two [DatabaseUrl]s are equal when every
	## component is.
	is_eq : _

	## The server config produced by strict parsing, with every field present.
	##
	## `protocol` is the protocol exactly as it was written, so `postgres://`
	## and `postgresql://` stay apart after parsing. An IPv6 `host` has had its
	## brackets removed (`[::1]` becomes `::1`), since the brackets are URL
	## syntax rather than part of the address.
	Config : {
		protocol : Str,
		host : Str,
		port : U16,
		user : Str,
		auth : [Password(Str), NoPassword],
		database : Str,
		options : Dict(Str, Str),
	}

	## The config produced by parsing a SQLite URL, strictly or leniently.
	SQLiteConfig : {
		path : Str,
		options : Dict(Str, Str),
	}

	## The result of lenient parsing with [DatabaseUrl.parse_partial]. Unlike
	## [DatabaseUrl], the protocols we know are not held to any requirements
	## either.
	PartialDatabaseUrl : [
		PostgreSQL(PartialConfig),
		MySQL(PartialConfig),
		SQLite(SQLiteConfig),
		Other(PartialConfig),
	]

	## [Config] with each optional field labelled as present or absent.
	PartialConfig : {
		protocol : Str,
		host : [Host(Str), NoHost],
		port : [Port(U16), NoPort],
		user : [User(Str), NoUser],
		auth : [Password(Str), NoPassword],
		database : [Database(Str), NoDatabase],
		options : Dict(Str, Str),
	}

	## Parses a database URL strictly. For PostgreSQL and MySQL the host, port,
	## user, and database are all required, and a missing one is an error
	## naming exactly what was missing.
	##
	## Supported formats:
	## - PostgreSQL: `postgresql://user:pass@host:port/database?options`
	##   (`postgres://` works too)
	## - MySQL: `mysql://user:pass@host:port/database?options`
	## - SQLite: `sqlite:///path/to/db.sqlite?options`
	## - Other: `protocol://user:pass@host:port/database?options`
	##
	## SQLite URLs are file paths, so none of the server fields apply and only
	## the path is extracted. Any other protocol is parsed as `Other` with the
	## fields labelled, because `redis://localhost:6379` is a perfectly good
	## redis URL and demanding a user or a database of it would be inventing a
	## requirement.
	##
	## Host, user, password, database, and option keys and values are
	## percent-decoded. The password may be empty (`user:@host`), which is
	## distinct from no password at all (`user@host`).
	##
	## ```
	## DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb?sslmode=require")
	## # Ok(PostgreSQL({
	## #     protocol: "postgresql",
	## #     host: "localhost",
	## #     port: 5432,
	## #     user: "user",
	## #     auth: Password("pass"),
	## #     database: "mydb",
	## #     options: Dict.from_list([("sslmode", "require")]),
	## # }))
	## ```
	parse : Str -> Try(DatabaseUrl, [InvalidPort(Str), MissingDatabase, MissingHost, MissingPort, MissingProtocol, MissingUser, RelativeUrl])
	parse = |url_str|
		match sqlite_remainder(url_str) {
			Ok(rest) => Ok(SQLite(parse_sqlite(rest)))
			Err(NotFound) => {
				uri = Uri.parse(url_str)
				protocol = protocol_of(uri)?

				match classify(protocol) {
					PostgreSQL => Ok(PostgreSQL(parse_server(uri, protocol)?))
					MySQL => Ok(MySQL(parse_server(uri, protocol)?))
					Other => Ok(Other(parse_server_partial(uri, protocol)?))
				}
			}
		}

	## Parses a database URL leniently. Unlike [DatabaseUrl.parse], a missing
	## host, port, user, or database is not an error for any protocol. Each of
	## those fields comes back labelled, `Host("localhost")` or `NoHost` and so
	## on, and no defaults are assumed. A port that was written but is not a
	## `U16` is still an error, since that is nonsense rather than absence.
	##
	## ```
	## # Gives Ok(PostgreSQL({ protocol: "postgresql", host: Host("localhost"), port: NoPort, user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))
	## DatabaseUrl.parse_partial("postgresql://localhost")
	## ```
	parse_partial : Str -> Try(PartialDatabaseUrl, [InvalidPort(Str), MissingProtocol, RelativeUrl])
	parse_partial = |url_str|
		match sqlite_remainder(url_str) {
			Ok(rest) => Ok(SQLite(parse_sqlite(rest)))
			Err(NotFound) => {
				uri = Uri.parse(url_str)
				protocol = protocol_of(uri)?
				config = parse_server_partial(uri, protocol)?

				match classify(protocol) {
					PostgreSQL => Ok(PostgreSQL(config))
					MySQL => Ok(MySQL(config))
					Other => Ok(Other(config))
				}
			}
		}
}

protocol_of : Uri -> Try(Str, [MissingProtocol, RelativeUrl, ..])
protocol_of = |uri|
	match Uri.scheme(uri) {
		Scheme(s) => Ok(s)
		SchemeRelative => Err(RelativeUrl)
		NoScheme => Err(MissingProtocol)
	}

## PostgreSQL and MySQL get their own tags, every other protocol is Other.
classify : Str -> [PostgreSQL, MySQL, Other]
classify = |protocol|
	if Str.caseless_ascii_equals(protocol, "postgresql") or Str.caseless_ascii_equals(protocol, "postgres") {
		PostgreSQL
	} else if Str.caseless_ascii_equals(protocol, "mysql") {
		MySQL
	} else {
		Other
	}

parse_server : Uri, Str -> Try(DatabaseUrl.Config, [InvalidPort(Str), MissingDatabase, MissingHost, MissingPort, MissingUser, ..])
parse_server = |uri, protocol| {
	host = 
		match Uri.host(uri) {
			Host(h) => host_str(h)
			EmptyHost | NoHost => return Err(MissingHost)
		}

	port = 
		match Uri.port(uri) {
			Ok(Port(p)) => p
			Ok(NoPort) => return Err(MissingPort)
			Err(PortParseErr(raw)) => return Err(InvalidPort(raw))
		}

	(user, auth) = 
		match Uri.userinfo(uri) {
			NoUserinfo => return Err(MissingUser)
			Userinfo(ui) => split_userinfo(ui)
		}

	database = 
		match database_from_path(Uri.path(uri)) {
			Database(db) => db
			NoDatabase => return Err(MissingDatabase)
		}

	Ok({ protocol, host, port, user, auth, database, options: Dict.from_list(Uri.query_params(uri)) })
}

parse_server_partial : Uri, Str -> Try(DatabaseUrl.PartialConfig, [InvalidPort(Str), ..])
parse_server_partial = |uri, protocol| {
	host = 
		match Uri.host(uri) {
			Host(h) => Host(host_str(h))
			EmptyHost | NoHost => NoHost
		}

	port = 
		match Uri.port(uri) {
			Ok(Port(p)) => Port(p)
			Ok(NoPort) => NoPort
			Err(PortParseErr(raw)) => return Err(InvalidPort(raw))
		}

	(user, auth) = 
		match Uri.userinfo(uri) {
			NoUserinfo => (NoUser, NoPassword)
			Userinfo(ui) => {
				(u, a) = split_userinfo(ui)
				(User(u), a)
			}
		}

	Ok({
		protocol,
		host,
		port,
		user,
		auth,
		database: database_from_path(Uri.path(uri)),
		options: Dict.from_list(Uri.query_params(uri)),
	})
}

## A host as a driver wants it: percent-decoded, and with the brackets of an
## IPv6 literal removed. A URL has to bracket `[::1]` so that the port colon
## stays unambiguous, but the address itself is `::1`.
host_str : Str -> Str
host_str = |raw|
	if Str.starts_with(raw, "[") and Str.ends_with(raw, "]") {
		decode_lenient(Str.drop_suffix(Str.drop_prefix(raw, "["), "]"))
	} else {
		decode_lenient(raw)
	}

## The userinfo is `user` or `user:password`, both percent-decoded. An empty
## password (`user:`) is still a password.
split_userinfo : Str -> (Str, [Password(Str), NoPassword])
split_userinfo = |ui|
	match Str.split_first(ui, ":") {
		Ok({ before, after }) => (decode_lenient(before), Password(decode_lenient(after)))
		Err(NotFound) => (decode_lenient(ui), NoPassword)
	}

## The database is the URL's path with its leading "/" removed,
## percent-decoded. An empty remainder means no database.
database_from_path : Str -> [Database(Str), NoDatabase]
database_from_path = |path| {
	decoded = decode_lenient(Str.drop_prefix(path, "/"))
	if Str.is_empty(decoded) {
		NoDatabase
	} else {
		Database(decoded)
	}
}

## The remainder of a SQLite URL after its prefix, or Err(NotFound) when the
## URL is not a SQLite one. SQLite URLs do not
## follow the standard URL format, so they get their own handling:
## `sqlite:///absolute/path`, `sqlite://./relative/path`, and
## `sqlite::memory:` all keep everything after the prefix as the path.
sqlite_remainder : Str -> Try(Str, [NotFound])
sqlite_remainder = |url_str|
	match Str.drop_prefix_caseless_ascii(url_str, "sqlite://") {
		Ok(rest) => Ok(rest)
		Err(NotFound) => Str.drop_prefix_caseless_ascii(url_str, "sqlite:")
	}

parse_sqlite : Str -> DatabaseUrl.SQLiteConfig
parse_sqlite = |rest|
	match Str.split_first(rest, "?") {
		Ok({ before, after }) => { path: decode_lenient(before), options: query_options(after) }
		Err(NotFound) => { path: decode_lenient(rest), options: Dict.empty() }
	}

## The same parsing [Uri.query_params] gives every other protocol, since a
## SQLite URL is only unusual before its `?`. A repeated key collapses in the
## `Dict` with the last one winning.
query_options : Str -> Dict(Str, Str)
query_options = |query_str|
	Dict.from_list(Uri.parse_query(query_str))

## Lenient percent-decoding: a malformed escape falls back to the raw text
## instead of failing.
decode_lenient : Str -> Str
decode_lenient = |text|
	match Uri.percent_decode(text) {
		Ok(decoded) => decoded
		Err(_) => text
	}

# =============================================================================
# Tests: strict parse
# =============================================================================

expect
	DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.empty() }))

expect
	DatabaseUrl.parse("postgresql://user@localhost/mydb") == Err(MissingPort)

expect
	DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb?sslmode=require&connect_timeout=10")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.from_list([("sslmode", "require"), ("connect_timeout", "10")]) }))

expect
	DatabaseUrl.parse("mysql://user:pass@localhost:3306/testdb")
		== Ok(MySQL({ protocol: "mysql", host: "localhost", port: 3306, user: "user", auth: Password("pass"), database: "testdb", options: Dict.empty() }))

expect
	DatabaseUrl.parse("mysql://user@localhost/mydb") == Err(MissingPort)

expect
	DatabaseUrl.parse("sqlite:///absolute/path/to/db.sqlite")
		== Ok(SQLite({ path: "/absolute/path/to/db.sqlite", options: Dict.empty() }))

expect
	DatabaseUrl.parse("sqlite://./relative/db.sqlite")
		== Ok(SQLite({ path: "./relative/db.sqlite", options: Dict.empty() }))

expect
	DatabaseUrl.parse("sqlite::memory:")
		== Ok(SQLite({ path: ":memory:", options: Dict.empty() }))

expect
# An unknown protocol is not held to PostgreSQL's requirements
	DatabaseUrl.parse("mongodb://localhost/mydb")
		== Ok(Other({ protocol: "mongodb", host: Host("localhost"), port: NoPort, user: NoUser, auth: NoPassword, database: Database("mydb"), options: Dict.empty() }))

expect
	DatabaseUrl.parse("mongodb://user:pass@localhost:27017/mydb")
		== Ok(Other({ protocol: "mongodb", host: Host("localhost"), port: Port(27017), user: User("user"), auth: Password("pass"), database: Database("mydb"), options: Dict.empty() }))

expect
# Redis URLs usually carry neither a user nor a database
	DatabaseUrl.parse("redis://localhost:6379")
		== Ok(Other({ protocol: "redis", host: Host("localhost"), port: Port(6379), user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))

expect
# A malformed port is nonsense whatever the protocol
	DatabaseUrl.parse("redis://localhost:banana") == Err(InvalidPort("banana"))

expect
# Percent-encoded password
	DatabaseUrl.parse("postgresql://user:p%40ss%21@localhost:5432/mydb")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: Password("p@ss!"), database: "mydb", options: Dict.empty() }))

expect
# Percent-encoded host, as used for Unix socket paths
	DatabaseUrl.parse("postgresql://user:pass@%2Fvar%2Frun%2Fpostgresql:5432/mydb")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "/var/run/postgresql", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.empty() }))

expect
# An IPv6 literal loses the brackets a URL needs but a driver does not
	DatabaseUrl.parse("postgresql://user:pass@[::1]:5432/mydb")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "::1", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.empty() }))

expect
	DatabaseUrl.parse("postgresql://user:pass@localhost:5432") == Err(MissingDatabase)

expect
# A trailing slash is still no database
	DatabaseUrl.parse("postgresql://user:pass@localhost:5432/") == Err(MissingDatabase)

expect
# postgres:// is an alias for postgresql://, and the protocol field keeps them apart
	DatabaseUrl.parse("postgres://user:pass@localhost:5432/mydb")
		== Ok(PostgreSQL({ protocol: "postgres", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.empty() }))

expect
# User without a password
	DatabaseUrl.parse("postgresql://user@localhost:5432/mydb")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: NoPassword, database: "mydb", options: Dict.empty() }))

expect
	DatabaseUrl.parse("postgresql://localhost:5432/mydb") == Err(MissingUser)

expect
# The authority is present but the host is empty
	DatabaseUrl.parse("postgresql://user:pass@:5432/mydb") == Err(MissingHost)

expect
# A port that was written but is not a U16
	DatabaseUrl.parse("postgresql://user:pass@localhost:banana/mydb") == Err(InvalidPort("banana"))

expect
	DatabaseUrl.parse("sqlite:///path/to/db.sqlite?mode=ro&cache=shared")
		== Ok(SQLite({ path: "/path/to/db.sqlite", options: Dict.from_list([("mode", "ro"), ("cache", "shared")]) }))

expect
# An empty password is distinct from no password
	DatabaseUrl.parse("postgresql://user:@localhost:5432/mydb")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: Password(""), database: "mydb", options: Dict.empty() }))

expect
# SQLite with an empty path (a temporary database)
	DatabaseUrl.parse("sqlite:") == Ok(SQLite({ path: "", options: Dict.empty() }))

# =============================================================================
# Tests: lenient parse
# =============================================================================

expect
	DatabaseUrl.parse_partial("postgresql://localhost")
		== Ok(PostgreSQL({ protocol: "postgresql", host: Host("localhost"), port: NoPort, user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))

expect
	DatabaseUrl.parse_partial("postgresql://localhost:5432")
		== Ok(PostgreSQL({ protocol: "postgresql", host: Host("localhost"), port: Port(5432), user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))

expect
	DatabaseUrl.parse_partial("mysql://user@localhost:3306/mydb")
		== Ok(MySQL({ protocol: "mysql", host: Host("localhost"), port: Port(3306), user: User("user"), auth: NoPassword, database: Database("mydb"), options: Dict.empty() }))

expect
	DatabaseUrl.parse_partial("sqlite::memory:") == Ok(SQLite({ path: ":memory:", options: Dict.empty() }))

expect
	DatabaseUrl.parse_partial("mongodb://localhost")
		== Ok(Other({ protocol: "mongodb", host: Host("localhost"), port: NoPort, user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))

expect
# Nonsense is still an error, even leniently
	DatabaseUrl.parse_partial("postgresql://localhost:banana") == Err(InvalidPort("banana"))

expect
# The host is percent-decoded leniently too
	DatabaseUrl.parse_partial("postgresql://%2Fvar%2Frun%2Fpostgresql")
		== Ok(PostgreSQL({ protocol: "postgresql", host: Host("/var/run/postgresql"), port: NoPort, user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))

expect
# And an IPv6 literal is unbracketed leniently too
	DatabaseUrl.parse_partial("postgresql://[::1]:5432")
		== Ok(PostgreSQL({ protocol: "postgresql", host: Host("::1"), port: Port(5432), user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))

expect
# For an unknown protocol there is nothing for strict parsing to be stricter
# about, so it reports what the lenient test above it reports
	DatabaseUrl.parse_partial("redis://localhost:6379")
		== Ok(Other({ protocol: "redis", host: Host("localhost"), port: Port(6379), user: NoUser, auth: NoPassword, database: NoDatabase, options: Dict.empty() }))

# =============================================================================
# Tests: case-insensitivity
# =============================================================================

expect
	DatabaseUrl.parse("POSTGRESQL://user:pass@localhost:5432/mydb")
		== Ok(PostgreSQL({ protocol: "POSTGRESQL", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.empty() }))

expect
	DatabaseUrl.parse("PostgreSQL://user:pass@localhost:5432/mydb")
		== Ok(PostgreSQL({ protocol: "PostgreSQL", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.empty() }))

expect
	DatabaseUrl.parse("MYSQL://user:pass@localhost:3306/mydb")
		== Ok(MySQL({ protocol: "MYSQL", host: "localhost", port: 3306, user: "user", auth: Password("pass"), database: "mydb", options: Dict.empty() }))

expect
	DatabaseUrl.parse("SQLITE::memory:") == Ok(SQLite({ path: ":memory:", options: Dict.empty() }))

expect
	DatabaseUrl.parse("SQLITE:///path/to/db.sqlite") == Ok(SQLite({ path: "/path/to/db.sqlite", options: Dict.empty() }))

# =============================================================================
# Tests: edge cases
# =============================================================================

expect
	DatabaseUrl.parse("") == Err(MissingProtocol)

expect
# A scheme-relative URL has no protocol to dispatch on
	DatabaseUrl.parse("//localhost:5432/mydb") == Err(RelativeUrl)

expect
# A query param without a value
	DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb?sslmode")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.from_list([("sslmode", "")]) }))

expect
# A query param with an empty value
	DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb?sslmode=")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.from_list([("sslmode", "")]) }))

expect
# A repeated key collapses and the last one wins
	DatabaseUrl.parse("postgresql://user:pass@localhost:5432/mydb?sslmode=require&sslmode=disable")
		== Ok(PostgreSQL({ protocol: "postgresql", host: "localhost", port: 5432, user: "user", auth: Password("pass"), database: "mydb", options: Dict.from_list([("sslmode", "disable")]) }))
