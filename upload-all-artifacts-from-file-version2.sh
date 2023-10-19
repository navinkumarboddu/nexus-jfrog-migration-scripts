#!/bin/bash

file_path="artifacts3.txt"

# Function to wait for the deployment to finish in Nexus
wait_for_deploy() {
    local repo_url="<url>/repository"
    local repository="$1"
    local group_id="$2"
    local artifact_id="$3"
    local version="$4"
    local file="$5"
    group_id=$(echo "$group_id" | sed 's/\./\//g')

  while true; do
    local api_url="${repo_url}/${repository}/${group_id}/${artifact_id}/${version}/${file}"
    echo "API URL: $api_url"
    local response=$(curl --insecure -s -o /dev/null -w "%{http_code}" "${api_url}")

    if [[ $response -eq 200 ]]; then
      echo "Deployment completed successfully."
      break
    else
      echo "Deployment failed. + $api_url"
      break
    fi
    sleep 10
  done
}

# Directory to search for jar files
directory=$1

echo "Directory:$directory"
path=$1
repositoryId=$(dirname "$path")
url=<url>/repository/$repositoryId

# Loop through each file path and extract the groupId, artifactId, version, and filename
upload(){
  local path=$1;
  
  # Extract the filename from the path
  filename=$(basename "$path")
  extension="${filename##*.}"
  
  # Extract the directory of the file
  dirpath=$(dirname "$path")
  
  # Extract the version (second last part)
  version=$(basename "$(dirname "$path")")

  # Extract the artifactId (part before version)
  artifactId=$(basename "$(dirname "$(dirname "$path")")")

  # Extract the groupId (part between "<repo-name>/downloaded-artifacts/" and artifactId)
  groupId=$(dirname "$(dirname "$(dirname "$path")")" | sed 's#$directory##' | tr '/' '.')
  dir_trim=$(echo "$directory" | tr '/' '.')
  
  # Trim the prefix "<repo-name>/downloaded-artifacts/" from groupId
  trimmedGroupId=${groupId#$dir_trim}
  #trimmedGroupId=${trimmedGroupId/./}
  
  # Output the extracted values
  #echo "*********************************************************************************"
  #echo "repository: $repositoryId"
  #echo "File path: $path"
  #echo "Group ID: $trimmedGroupId"
  #echo "Artifact ID: $artifactId"
  #echo "Version: $version"
  #echo "Filename: $filename"
  #echo "Packaging: $extension"
  #echo "Dirpath: $dirpath"
  #echo
  
  mvn_options="-DgroupId=$trimmedGroupId -DartifactId=$artifactId -Dversion=$version -DrepositoryId=$repositoryId -Durl=$url -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true"
  
  if [[ $filename == *".tar.gz" ]]; then
    mvn_options+=" -Dpackaging=tar.gz"
    if [[ $filename == *"-adapa-ws-client.tar.gz"* ]]; then
      mvn_options+=" -Dclassifier=adapa-ws-client"
    fi
  else
    mvn_options+=" -Dpackaging=$extension"
  fi
    
  # Check if sources.jar file exists
  #sources_jar=$(find $dirpath -type f -name "*sources.jar" -print -quit)
  #if [[ -n $sources_jar ]]; then
  #  mvn_options+=" -Dsources=$sources_jar"
  #fi

  # Check if javadoc.jar file exists
  #javadoc_jar=$(find "$dirpath" -type f -name "*javadoc.jar" -print -quit) 
  #if [[ -n $javadoc_jar ]]; then
  #  mvn_options+=" -Djavadoc=$javadoc_jar" 
  #fi
  
  # Check if tests.jar file exists
  tests_jar=$(find "$dirpath" -type f -name "*tests.jar" -print -quit)
  echo $tests_jar
  if [[ -n $tests_jar && $path =~ .*tests\.jar ]]; then
    mvn_options+=" -Dfile=$path -Djavadoc=$tests_jar -Dclassifier=tests"
    echo "Found Tests Jar..."
  else
    mvn_options+=" -Dfile=$path"
  fi


  echo "mvn_options: $mvn_options"
  
  # Execute mvn deploy command
  # mvn deploy:deploy-file $mvn_options
  
  local repo_url="<url>/repository"
  local modified_groupId=$(echo "$trimmedGroupId" | sed 's/\./\//g')
  local api_url="${repo_url}/${repositoryId}/${modified_groupId}/${artifactId}/${version}/${filename}"
  local response=$(curl --insecure -s -o /dev/null -w "%{http_code}" $api_url)

  echo "Checking if artifacts already deployed or not... $response + $api_url"
  if [[ $response == "200" ]]; then
    echo "Already Deployed"
  else
    echo "Deploying..."
    # Execute mvn deploy command
    mvn deploy:deploy-file $mvn_options
    
    # Wait for the deployment to finish
    #wait_for_deploy "$repositoryId" "$trimmedGroupId" "$artifactId" "$version" "$filename"
  fi

}

# Use find to search for jar files and echo their paths
#file_paths_jar=($(find "$directory" -type f -name "*.jar" ! -name "*sources.jar" ! -name "*javadoc.jar"))
file_paths_jar=($(find "$directory" -type f -name "*.zip"))

# Upload each jar file in sequential order
for jar_file in "${file_paths_jar[@]}"; do
  echo "Uploading: $jar_file"
  filename=$(basename "$jar_file")
  if grep -q "$filename" "$file_path"; then
   echo "Found file:$filename"
   upload "$jar_file"
   sed -i "\#$filename#d" "$file_path"
  fi
#  upload "$jar_file"
done

# Use find to search for pom files and echo their paths
file_paths_pom=$(find "$directory" -type d -exec sh -c '
  dir="$1"
  if [ "$dir" != "$directory" ]; then
    if [ -z "$(find "$dir" -type f \( -name "*.jar" -o -name "*javadoc.jar" -o -name "*sources.jar" \) -print -quit)" ]; then
      #if [ -n "$(find "$dir" -type f -name "*.pom" -print -quit)" ]; then
        echo "$dir"
      #fi
    fi
  fi
' sh {} \;)

# Function to check if a directory contains a *.pom file
contains_pom_file() {
  local dir="$1"
  if [[ -n $(find "$dir" -maxdepth 1 -type f -name "*.pom" -print -quit) ]]; then
    #echo "Contains pom"
    return 0
  else
    #echo "Does not contain pom"
    return 1
  fi
}

# Filter out parent directories without a *.pom file in the immediate folder
filtered_paths=()

for pom_file in $file_paths_pom; do
  #echo "$pom_file"
  if contains_pom_file "$pom_file"; then
    filtered_paths+=($(find "$pom_file" -maxdepth 1 -type f -name "*.pom" -print -quit))
  fi
done

# # Upload each pom file in sequential order
for pom_file in "${filtered_paths[@]}"; do
  #echo "Uploading: $pom_file"
#  upload "$pom_file"
  filename=$(basename "$pom_file")
  if grep -q "$filename" "$file_path"; then
    echo "Found file:$filename"
    #upload "$pom_file"
    sed -i "\#$filename#d" "$file_path"
  fi
done