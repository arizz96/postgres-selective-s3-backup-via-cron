#!/bin/bash

echo "`date` ~~~~~~~~~~~ STARTING CUSTOM BACKUP ~~~~~~~~~~~~"
mkdir -p /tmp/custom_dump
rm -f /tmp/custom_dump/*

STANDARD_TABLES=(${STANDARD_TABLES//, /$' '})
MASTER_CHILD_TABLES=(${MASTER_CHILD_TABLES//, /$' '})
MASTER_OBJ_IDS=${MASTER_OBJ_IDS//, /$', '}

PGDATABASE=$PGDATABASE
PGUSER=$PGUSER
PGPORT=${PGPORT:-5432}
PGHOST=${PGHOST:-localhost}

echo "MASTER_OBJ_TBL=${MASTER_OBJ_TBL}"
echo "MASTER_OBJ_IDS=${MASTER_OBJ_IDS[@]}"
echo "MASTER_OBJ_CLMN=${MASTER_OBJ_CLMN}"
echo "STANDARD_TABLES=${STANDARD_TABLES[@]}"
echo "MASTER_CHILD_TABLES=${MASTER_CHILD_TABLES[@]}"

CMD=$'COPY (SELECT * FROM '$MASTER_OBJ_TBL$' WHERE id IN ('$MASTER_OBJ_IDS$')) TO STDOUT DELIMITER \';\' CSV HEADER;\n'
psql -d $PGDATABASE -U $PGUSER -h $PGHOST -p $PGPORT -c "$CMD" > /tmp/custom_dump/$MASTER_OBJ_TBL.csv
for OBJECT in "${STANDARD_TABLES[@]}"
do
  CMD=$'COPY (SELECT * FROM '$OBJECT$') TO STDOUT DELIMITER \';\' CSV HEADER;\n'
  psql -d $PGDATABASE -U $PGUSER -h $PGHOST -p $PGPORT -c "$CMD" > /tmp/custom_dump/$OBJECT.csv
done

for OBJECT in "${MASTER_CHILD_TABLES[@]}"
do
  CMD=$'COPY (SELECT * FROM '$OBJECT$' WHERE '$MASTER_OBJ_CLMN$' IN ('$MASTER_OBJ_IDS$')) TO STDOUT DELIMITER \';\' CSV HEADER;\n'
  psql -d $PGDATABASE -U $PGUSER -h $PGHOST -p $PGPORT -c "$CMD" > /tmp/custom_dump/$OBJECT.csv
done

psql -d $PGDATABASE -U $PGUSER -h $PGHOST -p $PGPORT -c "$CMD"
pg_dump -s $PGDATABASE > /tmp/custom_dump/schema.sql

SEQUENCES=($(psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -t -c "SELECT sequence_name from information_schema.sequences;"))
echo '' > /tmp/custom_dump/sequences.sql
for SEQUENCE in "${SEQUENCES[@]}"
do
  CMD=$'SELECT \'SELECT setval(\'\' \' || \''$SEQUENCE$'\' || \' \'\', \' || last_value || \');\' FROM '$SEQUENCE$';'
  psql -d $PGDATABASE -U $PGUSER -h $PGHOST -p $PGPORT -t -c "$CMD" >> /tmp/custom_dump/sequences.sql
done

echo "Generating import script..."
echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -f schema.sql\n' > '/tmp/custom_dump/import_script.sh'
echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -f sequences.sql\n' >> '/tmp/custom_dump/import_script.sh'
echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -c \"ALTER TABLE '$MASTER_OBJ_TBL$' DISABLE TRIGGER ALL;\"\n' >> '/tmp/custom_dump/import_script.sh'
echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -c \"\COPY '$MASTER_OBJ_TBL$' FROM \''$MASTER_OBJ_TBL$'.csv\' DELIMITER \';\' CSV HEADER;\"\n' >> '/tmp/custom_dump/import_script.sh'
echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -c \"ALTER TABLE '$MASTER_OBJ_TBL$' ENABLE TRIGGER ALL;\"\n' >> '/tmp/custom_dump/import_script.sh'
for OBJECT in "${STANDARD_TABLES[@]}" "${MASTER_CHILD_TABLES[@]}"
do
  echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -c \"ALTER TABLE '$OBJECT$' DISABLE TRIGGER ALL;\"\n' >> '/tmp/custom_dump/import_script.sh'
  echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -c \"\COPY '$OBJECT$' FROM \''$OBJECT$'.csv\' DELIMITER \';\' CSV HEADER;\"\n' >> '/tmp/custom_dump/import_script.sh'
  echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -c \"ALTER TABLE '$OBJECT$' ENABLE TRIGGER ALL;\"\n' >> '/tmp/custom_dump/import_script.sh'
done
echo $'psql -d ${PGDATABASE} -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -c \"REINDEX DATABASE ${PGDATABASE};\"\n' >> '/tmp/custom_dump/import_script.sh'
chmod +x /tmp/custom_dump/import_script.sh

zip -r /tmp/custom_dump/backup.zip /tmp/custom_dump/

echo "`date` Uploading to S3"
/backup/s3upload.rb
echo "`date` Done!"
