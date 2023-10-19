#!/bin/bash

file_path=""

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
    echo $last_part
    local group_id_without_version=""
	# check if the version is present at the end of the last part of group_id
	if [[ "$last_part" == "$version" ]]; then
	  # remove the last part (i.e., version) from group_id to get group_id_without_version
	  group_id_without_version=$(echo "$group_id_v" | rev | cut -d '/' -f 2- | rev)
	else
    #if [[ $download_url =~ .*/([0-9.-]+)-[^/]+ ]]; then
    #    version="${BASH_REMATCH[1]}"
    #    echo "Version: $version"
    #else
        echo "Error: version not found in the download_url"
    #fi 
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
    echo "$filepath"
    
    if [ -f "$filepath" ]; then
        echo "File already exists. Skipping download."
    else
        curl -L -o "$filepath" "$download_url"
        echo "Downloading ......"
    fi

    #wget -q "$url" -O "$filename"
}



if [ -f "$file_path" ]; then
  echo "File Exists"
  # Read file contents into an array
  IFS=$'\n' read -d '' -r -a lines < "$file_path"
  
  # Loop through the lines array
  for downloadUrl in "${lines[@]}"; do
      echo "$downloadUrl"
      download_artifacts "$downloadUrl" "$file_path"
  done

  #while IFS= read -r downloadUrl; do
  #  echo "Processing URL: $downloadUrl"
  #  download_artifacts "$downloadUrl"  # Uncomment this line or add your own code here
  #done < "$file_path"
fi

echo "All artifacts downloaded to $DOWNLOAD_DIR"
