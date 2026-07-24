# MySQL 5.7 -> 9.7 migration

Chart 2.0.0 moves the bundled MySQL server from 5.7 to 9.7. MySQL only supports upgrades
between consecutive series (5.7 -> 8.0 -> 8.4 -> 9.7), so **retagging the image against the
existing data directory will not work**. The server has to be given a fresh volume and the
data reloaded logically.

The old PVC carries `helm.sh/resource-policy: keep`, so it survives this process untouched
and is the rollback path.

## 1. Pre-flight checks (blocking)

These are cheap and they fail late and badly if skipped.

**Client authentication.** MySQL removed `mysql_native_password` in 8.4, so 9.7 offers
`caching_sha2_password` only. Confirm both application images can handle it:

- `virnao/sense-orchestrator` — check the bundled Connector/J version. Over a non-TLS
  connection it will also need `allowPublicKeyRetrieval=true`, or a configured server public
  key, to complete the handshake.
- `virnao/sense-db-migration` — check the sqitch client's `libmysqlclient`.

**Reserved words.** MySQL 8.0 added `RANK`, `SYSTEM`, `GROUPS`, `LEAD`, `ROWS` and others.
Run the upgrade checker against the live 5.7 instance and grep the sqitch migrations for
unquoted uses:

```sh
mysqlcheck -u root -p --all-databases --check-upgrade
```

**Character set.** Record what the existing data actually uses — this decides whether you
need to set `mysql.charset` / `mysql.collation`:

```sh
mysql -u root -p -e "SELECT table_schema, table_name, table_collation
  FROM information_schema.tables
  WHERE table_schema IN ('rainsdb','frontend');"
```

Capture the full schema too, as the diff target for step 6:

```sh
mysqldump -u root -p --no-data --databases rainsdb frontend > schema-before.sql
```

MySQL 8.0 changed the server default from `latin1` to `utf8mb4`. Tables restored from a dump
keep the character set recorded in their `CREATE TABLE`, but *new* tables created by later
sqitch migrations would pick up the new server default. Mixing the two causes
"illegal mix of collations" at join time. If the existing data is not already `utf8mb4`, pin
`mysql.charset` and `mysql.collation` to match it.

## 2. Dump

`bin/mysql_dump.sh` already scopes to `--databases rainsdb frontend` and excludes the system
schema, which is what we want. Add `--set-gtid-purged=OFF` if GTIDs are enabled.

Verify the dump is complete and non-empty before continuing.

## 3. Quiesce

Scale the orchestrator to 0 so nothing writes during the cutover.

## 4. Fresh volume

Set `mysql.pvcName` to a new name (or leave `mysql.generatePVC: true` and rename), so 9.7
initializes a clean data directory. Do not reuse the 5.7 claim.

## 5. Deploy 9.7

Deploy chart 2.0.0. On an empty volume the entrypoint runs `a_preprocess.sql` from the
init ConfigMap, which creates `frontend` and `rainsdb`. (That only happens on a fresh
volume — `/docker-entrypoint-initdb.d/` is skipped when the data directory already exists,
which is exactly why step 4 matters.)

Watch that the pod reaches Ready without restarting. The startup probe allows roughly ten
minutes; if the import in the next step will take longer than that, raise
`mysql.probes.startup.custom` or disable the probes for the duration.

## 6. Reload and verify

Import the dump, then re-capture the schema and diff it:

```sh
mysqldump -u root -p --no-data --databases rainsdb frontend > schema-after.sql
diff schema-before.sql schema-after.sql
```

Differences in character set or collation are the thing to look for. Row counts per table
are worth spot-checking too.

## 7. Migrations and restart

Scale the orchestrator back up. The sqitch init containers run `deploy`, which is idempotent
and should report nothing to do if the dump was current. Then confirm the portal loads at
`/StackV-web/portal/`.

## Rollback

Point `mysql.pvcName` back at the retained 5.7 claim and redeploy the previous chart
version. Nothing in this process mutates the original volume.
