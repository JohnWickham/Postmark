# Postmark

Postmark is a command-line tool to simplify the publishing of [Markdown](https://daringfireball.net/projects/markdown) documents on the web. It watches a given content directory for changes to Markdown documents, generates static HTML files that can be served to browsers, and manages a SQLite database of articles.

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

Postmark organizes each post in its own folder within the watched content directory. A post folder contains the original Markdown document, generated HTML file, and resources/attachment files to serve alongside the post.

Each post folder is named with the unique slug of the post; the HTML file is named `index.html`; attachment files are left untouched inside the post folder. This allows the content directory to be served statically with no additional work.

If a Markdown document is added directly to the watched content directory without a containing post folder, Postmark will automatically create a post folder for it and move the document inside.

## Document Parsing

### Generating fragments

By default, Postmark generates fully-formed HTML documents for posts, including `<html>`, `<title>`, and `<body>` tags. This may be undesirable when generated content is not served statically. For example, incorporating generated markup into a templating system may result in duplicate document tags or page elements, like the article’s title.

Instead, Postmark can [generate HTML fragments](#using-postmark) that contain only markup for the body content of the article, ommitting the first heading element. Note that these files should not be served directly to browsers, as they won’t contain fully-formed HTML documents.

### Metadata

When creating database entries for a post, Postmark will [infer a number of its attributes](#posts)—like title and creation date—by analyzing its source Markdown document. To override the inferred values, Postmark will look for a metadata header at the start of Markdown documents:

```
---
title: A Mathematical Theory of Communication
created: 1948-07-13
updated: 2001-02-01
topics: Theories, Pulse-Code Modulation, Communication
---
```

The metadata header can specify the following properties:

- `title`
- `created` date (`YYYY-MM-DD` format)
- `updated` date (`YYYY-MM-DD` format)
- `preview` content
- `topics` as a comma-separated list of topic names (not slugs)
- `status` one of `public`, `private`, or `draft`

All properties are optional, and any other properties in the header are ignored.

## SQLite Database

Postmark maintains a SQLite database of articles it has processed. This allows other applications to provide options for browsing content that are more robust than static serving. To specify a database file, see [Using Postmark](#using-postmark).

The Postmark database has three tables:

- Posts (`posts`)
- Topics (`topics`)
- Post-Topic Relationships (`post_topic`)

Each entity in the database is uniquely identified by its `slug` (a URL-safe version of its title or name).

### Posts

Column | Type | Description
-------|------|------------
`slug` | String | A URL-safe version of the post’s title. Unique, primary key.
`title` | String | The post’s title. Derived from the first first-level heading in the post’s Markdown document, `title` property in the Markdown document’s metadata header, or Markdown document’s filename, in that order.
`createdDate` | Date | The date that the article was written. Inferred from the creation date of the post’s Markdown file, or `created` property (in `YYYY-MM-DD` format) in the Markdown document’s metadata header, in that order.
`updatedDate` | Date (optional) | The date that the article was last updated. Inferred from the modification date of the post’s Markdown file, or `updated` property (in `YYYY-MM-DD` format) in the Markdown document’s metadata header, in that order.
`publishStatus` | String (`public`, `draft`, or `private`) | The status of the article. This property has no effect on Postmark’s processing; it is present in the database only to assist querying clients in selecting appropriate content to display.
`previewContent` | String (optional) | Preview content/excerpt for the article. Inferred by truncating the first paragraph-level content from the post’s Markdown document, or the `preview` property in the Markdown document’s metadata header.
`hasGeneratedContent` | Bool (optional) | Whether Postmark has processed the article and generated a static HTML file for it.

### Topics

Column | Type | Description
-------|------|------------
`slug` | String | A URL-safe version of the topic’s title. Unique, primary key.
`title` | String | The display name of the topic.

### Post-Topic Relationships

Column | Type | Description
-------|------|------------
`postSlug` | Foreign key (`post.slug`) | The slug of the related post.
`topicSlug` | Foreign key (`topic.slug`) | The slug of the related topic.

This table has a compound primary key constraint on both of its columns.
