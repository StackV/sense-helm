#
# Copy-paste these scripts within the mysql container, and copy the files from the mounted directory.
# > Combo dumps.
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb frontend -n >/var/lib/mysql/all_dump.sql
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb frontend -n -d >/var/lib/mysql/all_raw_dump.sql

# > Frontend-only dumps.
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases frontend -n >/var/lib/mysql/frontend_dump.sql
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases frontend -n -d >/var/lib/mysql/frontend_raw_dump.sql

# > Rainsdb dumps.
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb -n >/var/lib/mysql/rainsdb_dump.sql
mysqldump -h 127.0.0.1 -P 3306 -u root -p$DBPASS --add-drop-table --databases rainsdb -n -d >/var/lib/mysql/rainsdb_raw_dump.sql

#
# > Once the SQL scripts have been moved, you can use the following commands to create a ConfigMap.
#   after which you can add the optional labels to match the rest of the app chart.
kubectl create configmap mysql-init-dump --from-file=./a_preprocess.sql --from-file=./raw/all_dump.sql --from-file=./z_postprocess.sql -o yaml --dry-run=client >mysql-init-dump.yaml
kubectl create configmap mysql-init-raw --from-file=./a_preprocess.sql --from-file=./raw/all_raw_dump.sql --from-file=./z_postprocess.sql -o yaml --dry-run=client >mysql-init-raw.yaml
