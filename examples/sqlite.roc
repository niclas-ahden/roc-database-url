app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.22.1/DobkAk7zNyqAgqh2Riaj5c5DtWtKhd5iVYE5RFa6izcd.tar.zst",
	db: "../package/main.roc",
}

import pf.Stdout
import db.DatabaseUrl

# Parsing SQLite URLs. Run it with: roc examples/sqlite.roc
#
# SQLite URLs are file paths, so they have no host, port, user, or password.

main! = |_| {
	urls = [
		# In-memory database
		"sqlite::memory:",
		# Absolute path
		"sqlite:///absolute/path/to/database.db",
		# Relative path
		"sqlite://./relative/path/to/database.db",
		# Simple filename
		"sqlite:mydb.sqlite",
		# With options such as mode (ro, rw, rwc, memory) and cache (shared, private)
		"sqlite:///path/to/db.sqlite?mode=rw&cache=shared",
		# Journal mode option
		"sqlite:///path/to/db.sqlite?_journal_mode=WAL",
	]

	for url in urls {
		Stdout.line!("=== Parsing: ${url} ===")?

		match DatabaseUrl.parse(url) {
			Ok(SQLite(config)) => {
				Stdout.line!("  Path: ${config.path}")?
				print_options!(config.options)?
			}

			Ok(_) => Stdout.line!("  Expected a SQLite URL")?
			Err(err) => Stdout.line!("  Error: ${Str.inspect(err)}")?
		}
	}

	Ok({})
}

print_options! = |options| {
	for pair in Dict.to_list(options) {
		(key, value) = pair
		Stdout.line!("  Option: ${key} = ${value}")?
	}

	Ok({})
}
