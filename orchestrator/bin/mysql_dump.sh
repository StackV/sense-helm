#
# Copy-paste these scripts within the mysql container, and copy the files from the mounted directory.
# > Combo dumps.
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb frontend -n >/tmp/schema_and_data.sql
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb frontend -n -d >/tmp/schema.sql

# # > Frontend-only dumps.
# mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases frontend -n >/tmp/frontend_dump.sql
# mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases frontend -n -d >/tmp/frontend_raw_dump.sql

# # > Rainsdb dumps.
# mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb -n >/tmp/rainsdb_dump.sql
# mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb -n -d >/tmp/rainsdb_raw_dump.sql
