#
# Copy-paste these scripts within the mysql container, and copy the files from the mounted directory.
# > Combo DB dumps.
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DB_PASS --skip-add-drop-table --databases rainsdb frontend -n >/tmp/schema_and_data.sql
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DB_PASS --skip-add-drop-table --databases rainsdb frontend -n -d >/tmp/schema.sql
