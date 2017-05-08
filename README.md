# Docker Postgres backup to Amazon S3 via cron

This image selective-dumps your postgres databases every hour (OR custom cron defined in `BACKUP_CRON_SCHEDULE`),
compresses the dump using zip and uploads it to an
amazon S3 bucket. Backups older than 30 days (OR days defined in `AWS_KEEP_FOR_DAYS`) are
deleted automatically.

It creates a group of .csv files, a schema.sql for database schema definition and a script to import all.

To import, use:
`PGPASSWORD=password PGUSER=user ./import_script.sh`

Configure the backup source and s3 target with these environment
variables:

- `AWS_REGION` (for example `eu-central-1`)
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_BUCKET_NAME`
- `AWS_KEEP_FOR_DAYS`
- `BACKUP_PATH`
- `BACKUP_CRON_SCHEDULE`
- `MASTER_OBJ_TBL` main table to export
- `MASTER_OBJ_IDS` objects' ids of main table to export
- `MASTER_OBJ_CLMN` main table reference column in (see below)
- `MASTER_CHILD_TABLES` childrens tables referenced by main table to export
- `STANDARD_TABLES` other tables to export
- `PGHOST`
- `PGDATABASE`
- `PGPORT`
- `PGUSER`
- `PGPASSWORD`

Example:
This is our schema in pg database:
`users(id, name, age)`
`blogs(id, name, description)`
`comments(id, user_id, blog_id, text, timestamp)`
`images(id, blog_id, url)`

We want to export `blogs`, `users` and users' related `comments`. We don't want `images`.
But we want a SELECTIVE dump, because we have 10k users and 1mln of comments in total, so we want to limit to users' ids `1` and `2`
To export, assuming database name is `test` and admin user is `postgres`, we lauch:
`PGDATABASE=test PGUSER=postgres MASTER_OBJ_TBL="users" MASTER_OBJ_IDS="1, 2" MASTER_OBJ_CLMN="user_id" MASTER_CHILD_TABLES="comments" STANDARD_TABLES="blogs" ./export_script.sh`

Now, a `schema.sql`, `.csv` files will be created and a file called `import_script.sh`. All of this will be zipped into `backup.zip` adn uploaded to S3 storage.
