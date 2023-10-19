#!/bin/bash

# Function to wait for the deployment to finish in Nexus
file_path="artifacts2.txt"

# Set the Nexus repository URL and repository name
NEXUS_URL=""
REPO_NAMES=""

for REPO_NAME in $REPO_NAMES; do
    echo $REPO_NAME
    # Make the initial search API call to get the first page of artifacts
    response=$(curl -v -k -X GET "$NEXUS_URL/service/rest/v1/search/assets" \
        -H "accept: application/json" \
        -G -d "repository=$REPO_NAME")
    #echo "$response" | jq '.'
    
    # Loop through all pages of artifacts using the continuationToken
    while true; do
       for row in $(echo "$response" | jq -r '.items[] | @base64'); do
      	  _jq() {
      	    echo "${row}" | base64 --decode | jq -r "${1}"
      	  }
    
      	  downloadUrl=$(_jq '.downloadUrl')
          if echo "$downloadUrl" | grep -E "\.(pom|war|jar|ear|zip|tar\.gz)$" >/dev/null; then
              echo $downloadUrl
              # Use sed to remove the line containing the URL
              #grep -vFx "$downloadUrl" "$file_path" | sponge "$file_path"
              sed -i "\#$downloadUrl#d" "$file_path"
          fi
       
       done
       
        # Check if there are more pages of artifacts
        continuation_token=$(echo "$response" | jq -r '.continuationToken')
        echo "continuation_token: $continuation_token"
        if [[ "$continuation_token" == "null" ]]; then
            break
        fi
    
        # Make the next search API call using the continuationToken
        response=$(curl -s -k -X GET "$NEXUS_URL/service/rest/v1/search/assets" \
            -H "accept: application/json" \
            -G -d "repository=$REPO_NAME" \
            -d "continuationToken=$continuation_token")
    done
done
echo "Verified Artifacts complete"
