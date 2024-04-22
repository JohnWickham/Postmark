# Postmark

Postmark is a command-line tool for publishing file-based Markdown writing on the web. It watches a given content directory for changes to Markdown documents, generates static HTML files that can be served to browsers, and manages a SQLite database of articles.

Postmark is written in Swift and supports macOS and Linux.

## Using Postmark

### Watch a directory
To watch a directory and automatically generate for changes to Markdown files: `postmark watch [<content-directory-url>] [--db <db>]`.

`<content-directory-url>` defaults to the current working directory.

Example: `postmark watch /opt/posts/content/`

Options:

- `--db, --database-file`: Specify a path to the database file. Defaults to `store.sqlite` in the current working directory.

### Regenerate content
To regenerate all content and/or database entries: `postmark regenerate [<content-directory-url>] [--db <db>] [--db-only <db-only>] [--dry-run]`.

`<content-directory-url>` defaults to the current working directory.

Options:

- `--db, --database-file`: Specify a path to the database file. Defaults to `store.sqlite` in the current working directory.
- `--db-only, --database-only`: Regenerate database entries without altering static content files. (default: false).
- `--dry-run`: Output a summary of all changes to be made, without actaully committing them.

## File Organization

Postmark organizes each post in its own folder within the watched content directory. A post folder contains the original Markdown document, generated HTML file, and resources/attachment files to serve alongside the post. The post folder is named with the unique slug of the post; the HTML file is named `index.html`; attachment files are left untouched inside the post folder. This allows the content directory to be served statically with no additional work.

## SQLite Database

Postmark maintains a SQLite database of articles it has processed. This allows other applications to provide options for browsing content that are more robust than static serving. To specify a database file, see [Using Postmark][#using-postmark].

The Postmark database has three tables:

- Posts (`posts`)
- Topics (`topics`)
- Post-Topic Relationships (`post_topic`)

Each entity in the database is uniquely identified by its `slug` (a URL-safe version of its title or name).
