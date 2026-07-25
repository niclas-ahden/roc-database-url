app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.22.1/DobkAk7zNyqAgqh2Riaj5c5DtWtKhd5iVYE5RFa6izcd.tar.zst",
	db: "../package/main.roc",
}

import pf.Stdout
import db.DatabaseUrl

# Strict parsing of PostgreSQL URLs. Run it with: roc examples/postgresql.roc

main! = |_| {
	urls = [
		# Missing user and port, so strict parsing fails
		"postgresql://localhost",
		# Missing user
		"postgresql://localhost:5432",
		# Missing port
		"postgresql://user:pass@localhost/mydb",
		# Full URL with all components
		"postgresql://user:pass@db.example.com:5432/production",
		# The postgres:// alias
		"postgres://user:pass@localhost:5432/mydb",
		# With query parameters
		"postgresql://user:pass@localhost:5432/mydb?sslmode=require&connect_timeout=10",
		# With a percent-encoded password
		"postgresql://user:p%40ss%21@localhost:5432/mydb",
		# With a percent-encoded user, password, and database
		"postgresql://my%20user:my%2Bpass@localhost:5432/my%2Ddb",
	]

	for url in urls {
		Stdout.line!("=== Parsing: ${url} ===")?

		match DatabaseUrl.parse(url) {
			Ok(PostgreSQL(config)) => {
				Stdout.line!("  Host: ${config.host}")?
				Stdout.line!("  Port: ${config.port.to_str()}")?
				Stdout.line!("  User: ${config.user}")?
				Stdout.line!("  Auth: ${Str.inspect(config.auth)}")?
				Stdout.line!("  Database: ${config.database}")?
				print_options!(config.options)?
			}

			Ok(_) => Stdout.line!("  Expected a PostgreSQL URL")?
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
