app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.22.1/DobkAk7zNyqAgqh2Riaj5c5DtWtKhd5iVYE5RFa6izcd.tar.zst",
	db: "../package/main.roc",
}

import pf.Stdout
import db.DatabaseUrl

# Lenient parsing with DatabaseUrl.parse_partial. Run it with: roc examples/partial.roc
#
# Unlike DatabaseUrl.parse, a missing host, port, user, or database is not an
# error. Each field comes back labelled, such as Host("localhost") or NoHost,
# and no defaults are assumed.

main! = |_| {
	urls = [
		# These would all fail strict parsing
		"postgresql://localhost",
		"postgresql://localhost:5432",
		"postgresql://user@localhost",
		"postgresql://user@localhost/mydb",
		# A complete URL works with both parse and parse_partial
		"postgresql://user:pass@localhost:5432/mydb",
		# Other protocols work too
		"mysql://localhost/testdb",
		"mongodb://user@db.example.com",
		# Nonsense is still an error, even leniently
		"postgresql://localhost:banana",
	]

	for url in urls {
		Stdout.line!("=== Parsing: ${url} ===")?

		match DatabaseUrl.parse_partial(url) {
			Ok(PostgreSQL(config)) | Ok(MySQL(config)) => {
				Stdout.line!("  Host: ${Str.inspect(config.host)}")?
				Stdout.line!("  Port: ${Str.inspect(config.port)}")?
				Stdout.line!("  User: ${Str.inspect(config.user)}")?
				Stdout.line!("  Auth: ${Str.inspect(config.auth)}")?
				Stdout.line!("  Database: ${Str.inspect(config.database)}")?
			}

			Ok(Other(config)) => {
				Stdout.line!("  Protocol: ${config.protocol}")?
				Stdout.line!("  Host: ${Str.inspect(config.host)}")?
				Stdout.line!("  User: ${Str.inspect(config.user)}")?
				Stdout.line!("  Database: ${Str.inspect(config.database)}")?
			}

			Ok(SQLite(config)) => Stdout.line!("  Path: ${config.path}")?
			Err(err) => Stdout.line!("  Error: ${Str.inspect(err)}")?
		}
	}

	Ok({})
}
