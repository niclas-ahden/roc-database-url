app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.22.1/DobkAk7zNyqAgqh2Riaj5c5DtWtKhd5iVYE5RFa6izcd.tar.zst",
	db: "../package/main.roc",
}

import pf.Stdout
import db.DatabaseUrl

# Strict parsing of MySQL URLs. Run it with: roc examples/mysql.roc

main! = |_| {
	urls = [
		# Missing user and port, so strict parsing fails
		"mysql://localhost",
		# Missing user
		"mysql://localhost:3306",
		# Missing port
		"mysql://user:pass@localhost/mydb",
		# Full URL with all components
		"mysql://user:pass@db.example.com:3306/production",
		# With common MySQL options
		"mysql://user:pass@localhost:3306/mydb?charset=utf8mb4&parseTime=true",
		# With a percent-encoded password containing an @
		"mysql://user:p%40ss%21@localhost:3306/mydb",
	]

	for url in urls {
		Stdout.line!("=== Parsing: ${url} ===")?

		match DatabaseUrl.parse(url) {
			Ok(MySQL(config)) => {
				Stdout.line!("  Host: ${config.host}")?
				Stdout.line!("  Port: ${config.port.to_str()}")?
				Stdout.line!("  User: ${config.user}")?
				Stdout.line!("  Auth: ${Str.inspect(config.auth)}")?
				Stdout.line!("  Database: ${config.database}")?
				print_options!(config.options)?
			}

			Ok(_) => Stdout.line!("  Expected a MySQL URL")?
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
