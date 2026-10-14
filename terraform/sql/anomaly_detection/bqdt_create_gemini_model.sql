CREATE OR REPLACE MODEL `${model}`
REMOTE WITH CONNECTION `${connection}`
OPTIONS (
endpoint = '${endpoint}'
);