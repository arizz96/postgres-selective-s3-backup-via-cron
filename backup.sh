#!/bin/bash

echo "`date` ~~~~~~~~~~~ STARTING CUSTOM BACKUP ~~~~~~~~~~~~"
mkdir -p /tmp/custom_dump
rm -f /tmp/custom_dump/*

STANDARD_TABLES=(${STANDARD_TABLES//, /$' '})
MASTER_CHILD_TABLES=(${MASTER_CHILD_TABLES//, /$' '})
MASTER_OBJ_IDS=${MASTER_OBJ_IDS//, /$', '}

echo "MASTER_OBJ_TBL=${MASTER_OBJ_TBL}"
echo "MASTER_OBJ_IDS=${MASTER_OBJ_IDS[@]}"
echo "MASTER_OBJ_CLMN=${MASTER_OBJ_CLMN}"
echo "STANDARD_TABLES=${STANDARD_TABLES[@]}"
echo "MASTER_CHILD_TABLES=${MASTER_CHILD_TABLES[@]}"

CMD=$'COPY (SELECT * FROM '$MASTER_OBJ_TBL$' WHERE id IN ('$MASTER_OBJ_IDS$')) TO \'/tmp/custom_dump/'$MASTER_OBJ_TBL$'.csv\' DELIMITER \';\' CSV HEADER;\n'
for OBJECT in "${STANDARD_TABLES[@]}"
do
  CMD=$CMD$'COPY (SELECT * FROM '$OBJECT$') TO \'/tmp/custom_dump/'$OBJECT$'.csv\' DELIMITER \';\' CSV HEADER;\n'
done

for OBJECT in "${MASTER_CHILD_TABLES[@]}"
do
  CMD=$CMD$'COPY (SELECT * FROM '$OBJECT$' WHERE '$MASTER_OBJ_CLMN$' IN ('$MASTER_OBJ_IDS$')) TO \'/tmp/custom_dump/'$OBJECT$'.csv\' DELIMITER \';\' CSV HEADER;\n'
done

psql -d $PGDATABASE -U $PGUSER -c "$CMD"
pg_dump -s $PGDATABASE > /tmp/custom_dump/schema.sql

echo "Generating import script..."
echo $'psql -d ${PGDATABASE} -U ${PGUSER} -f schema.sql\n' > '/tmp/custom_dump/import_script.sh'
CMD=$'\COPY '$MASTER_OBJ_TBL$' FROM \''$MASTER_OBJ_TBL$'.csv\' DELIMITER \';\' CSV HEADER;\n'
for OBJECT in "${STANDARD_TABLES[@]}" "${STANDARD_TABLES[@]}"
do
  CMD=$CMD$'\COPY '$OBJECT$' FROM \''$OBJECT$'.csv\' DELIMITER \';\' CSV HEADER;\n'
done
CMD=$'psql -d ${PGDATABASE} -U ${PGUSER} -c "'"$CMD"'"'
echo $CMD >> '/tmp/custom_dump/import_script.sh'

zip -r /tmp/custom_dump/backup.zip /tmp/custom_dump/
