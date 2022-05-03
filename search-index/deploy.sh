      #!/bin/bash
      set -x

      # Constants
      SEARCH_SERVICE_APIVERSION="2021-04-30-Preview"

      # Define variables
      WORKING_DIRECTORY=$1
      STORAGE_RESOURCE_ID="$2"
      STORAGE_ACCOUNT_CONTAINER="$3"

      SEARCH_SERVICE_ENDPOINT="$4"
      SEARCH_SERVICE_SECRET="$5"

      COGNITIVE_SERVICE_SECRET="$6"
      FUNCTION_NAME="$7"
      FUNCTION_APICODE="$8"
      
      
      INDEX_NAME="km"
      INDEXER_NAME="km-indexer"
      DATA_SOURCE_NAME="azstorage"
      SKILLS_NAME="km-skills"
      
      # Create Data Source
      DATA_SOURCE_FILE="${WORKING_DIRECTORY}/datasource.json"
      BASE_DATA_SOURCE_FILE="${WORKING_DIRECTORY}/base-datasource.json"

      sed -e "s~__STORAGE_RESOURCE_ID__~${STORAGE_RESOURCE_ID}~g" $BASE_DATA_SOURCE_FILE > $DATA_SOURCE_FILE
      sed -i "s/__STORAGE_CONTAINER__/${STORAGE_ACCOUNT_CONTAINER}/g" $DATA_SOURCE_FILE 

      curl --request PUT \
      --url "${SEARCH_SERVICE_ENDPOINT}/datasources/${DATA_SOURCE_NAME}/?api-version=${SEARCH_SERVICE_APIVERSION}" \
      --header 'Content-Type: application/json' \
      --header "api-key: ${SEARCH_SERVICE_SECRET}" \
      --header 'cache-control: no-cache' \
      --data @"${DATA_SOURCE_FILE}"

      # Create Index
      INDEX_FILE="${WORKING_DIRECTORY}/base-index.json"

      curl --request PUT \
      --url "${SEARCH_SERVICE_ENDPOINT}/indexes/${INDEX_NAME}/?api-version=${SEARCH_SERVICE_APIVERSION}" \
      --header 'Content-Type: application/json' \
      --header "api-key: ${SEARCH_SERVICE_SECRET}" \
      --header 'cache-control: no-cache' \
      --data @"${INDEX_FILE}"

      # Create Skills
      SKILLS_FILE="${WORKING_DIRECTORY}/skills.json"
      BASE_SKILLS_FILE="${WORKING_DIRECTORY}/base-skills.json"
     
      sed -e "s/__COG_SERVICES_KEY__/${COGNITIVE_SERVICE_SECRET}/g" $BASE_SKILLS_FILE > $SKILLS_FILE
      sed -i "s/__FUNCTION_NAME__/${FUNCTION_NAME}/g" $SKILLS_FILE 
      sed -i "s/__FUNCTION_APICODE__/${FUNCTION_APICODE}/g" $SKILLS_FILE 


      curl --request PUT \
      --url "${SEARCH_SERVICE_ENDPOINT}/skillsets/${SKILLS_NAME}/?api-version=${SEARCH_SERVICE_APIVERSION}" \
      --header 'Content-Type: application/json' \
      --header "api-key: ${SEARCH_SERVICE_SECRET}" \
      --header 'cache-control: no-cache' \
      --data @"${SKILLS_FILE}"

      # Create Indexer
      INDEXER_FILE="${WORKING_DIRECTORY}/indexer.json"
      BASE_INDEXER_FILE="${WORKING_DIRECTORY}/base-indexer.json"

      sed -e "s/__DATASOURCE_NAME__/${DATA_SOURCE_NAME}/g" $BASE_INDEXER_FILE > $INDEXER_FILE
      sed -i "s/__INDEX_NAME__/${INDEX_NAME}/g" $INDEXER_FILE 
      sed -i "s/__SKILLSET_NAME__/${SKILLS_NAME}/g" $INDEXER_FILE 

      curl --request PUT \
      --url "${SEARCH_SERVICE_ENDPOINT}/indexers/${INDEXER_NAME}/?api-version=${SEARCH_SERVICE_APIVERSION}" \
      --header 'Content-Type: application/json' \
      --header "api-key: ${SEARCH_SERVICE_SECRET}" \
      --header 'cache-control: no-cache' \
      --data @"${INDEXER_FILE}"
