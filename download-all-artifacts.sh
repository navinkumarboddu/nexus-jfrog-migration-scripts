#!/bin/bash

# Set the Nexus repository URL and repository name
NEXUS_URL=""
REPO_NAME=""
GROUP_ID=""
ARTIFACT_ID=""

# Set the directory to download artifacts to
DOWNLOAD_DIR=""
mkdir -p "$DOWNLOAD_DIR"

function download_artifacts(){ 
    local download_url=$1
    local filename=$(basename "$download_url")
    #local group_id=$(echo "$download_url" | sed -e "s|$NEXUS_URL/repository/$REPO_NAME/||" -e "s|/$filename||" -e "s|/|.|g")
    #echo "Group_id : $group_id"
    local version=$(echo "$download_url" | awk -F"/" '{print $(NF-1)}')
    
    group_id_v=$(echo "$download_url" | sed -e "s|http://[^/]\+/repository/$REPO_NAME/\(.*\)/[^/]\+$|\1|g")
    echo "Group ID: $group_id_v"
	    
    # extract the last part of the group_id which should be the version
    last_part=$(echo "$group_id_v" | rev | cut -d '/' -f 1 | rev)

    local group_id_without_version=""
	# check if the version is present at the end of the last part of group_id
	if [[ "$last_part" == "$version" ]]; then
	  # remove the last part (i.e., version) from group_id to get group_id_without_version
	  group_id_without_version=$(echo "$group_id_v" | rev | cut -d '/' -f 2- | rev)
	else
	  echo "Error: version not found at the end of group_id"
	fi
    
    echo "Group ID without version: $group_id_without_version"
    echo "Version: $version"

    filepath="/opt/downloaded-artifacts/$group_id_without_version/${version}"
    echo "Filepath: $filepath"
    
    mkdir -p "$filepath"
    chmod -R 777 "$filepath"
    
    if [ -d "$filepath" ]; then
	     echo "$filepath Directory exists."
    else
	     echo "Directory does not exist."
	     mkdir -p "$filepath"
       chmod -R 777 "$filepath"
    fi  

    echo "Downloading $filename to $filepath"
    cd "$filepath"
    filepath="/opt/downloaded-artifacts/$group_id_without_version/${version}/$filename"
      
    filepath="/opt/downloaded-artifacts/$group_id_without_version/${version}/$filename"
    echo "$download_url"
    
    if [ -f "$filepath" ]; then
        echo "File already exists. Skipping download."
    else
        curl -L -o "$filepath" "$download_url"
        echo "Downloading ......"
    fi

    #wget -q "$url" -O "$filename"
}

# Make the initial search API call to get the first page of artifacts
response=$(curl -v -X GET "$NEXUS_URL/service/rest/v1/search/assets" \
    -H "accept: application/json" \
    -G -d "repository=$REPO_NAME" \
    -d "group=$GROUP_ID")
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
       download_artifacts $downloadUrl
    fi  
   done
   
    # Check if there are more pages of artifacts
    continuation_token=$(echo "$response" | jq -r '.continuationToken')
    echo "continuation_token: $continuation_token"
    if [[ "$continuation_token" == "null" ]]; then
        break
    fi

    # Make the next search API call using the continuationToken
    response=$(curl -s -X GET "$NEXUS_URL/service/rest/v1/search/assets" \
        -H "accept: application/json" \
        -G -d "repository=$REPO_NAME" \
        -d "group=$GROUP_ID" \
        -d "continuationToken=$continuation_token")
done

echo "All artifacts downloaded to $DOWNLOAD_DIR"
