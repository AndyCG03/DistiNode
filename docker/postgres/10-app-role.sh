#!/bin/sh
# Crea el rol con el que se conecta la app: sin superusuario ni BYPASSRLS, para que RLS se aplique.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -v pw="$APP_DB_PASSWORD" <<'EOSQL'
create role distinode_app login password :'pw' nosuperuser nobypassrls;
EOSQL
