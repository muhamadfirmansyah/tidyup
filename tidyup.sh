#!/bin/bash

# Check if the user provided an argument
if [[ $# -eq 0 ]]; then
    echo "Usage: tidyup [FOLDER_LOCATION]"
    exit 1
fi

folder_location="$1"

# Check if the folder exists
if [[ ! -d "$folder_location" ]]; then
    echo "Error: Folder not found."
    exit 1
fi

# Change to the folder location
cd "$folder_location" || exit 1

# Perform your tidy-up operations here
echo "Running tidyup in: $(pwd)"

# Set your AI API credentials and endpoint
API_KEY="" # INPUT YOUR API KEY HERE
API_ENDPOINT="" # INPUT YOUR API PROVIDER ENDPOINT EXAMPLE: https://openrouter.ai/api/v1/chat/completions
MODEL="" # INPUT YOUR PREFERED MODEL EXAMPLE: google/gemini-2.0-flash-exp:free

# Use the current folder as the target
CURRENT_FOLDER="$(pwd)"

# Function to extract file name and extension
get_file_details() {
    local file_path="$1"
    local file_name file_extension

    file_name=$(basename "$file_path")            # Get file name
    file_extension="${file_name##*.}"            # Get file extension
    file_extension=$(echo "$file_extension" | tr '[:upper:]' '[:lower:]')  # Normalize to lowercase

    echo "$file_name|$file_extension"
}

# Function to ask AI for grouping suggestions
get_ai_grouping() {
    local file_list="$1"

    response=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$MODEL"'",
            "prompt": "You are a file organizer AI. Given the following list of files, suggest folder names to group them. Format the output as: \nfilename -> folder\nfilename -> folder. \n\nUse \"General\" if no specific folder applies. Here are the files:\n'"$file_list"'",
            "max_tokens": 10000,
        }')

    # Extract the response from the JSON output
    echo "$response" | jq -r '.choices[0].text' | sed 's/\\n/\n/g' | sed 's/^"//;s/"$//'
}

# List all files and folders in the current directory
echo "Listing files and folders in: $CURRENT_FOLDER"
file_details=""
for item in "$CURRENT_FOLDER"/*; do
    if [[ -f "$item" && "$(basename "$item")" != "tidyup.sh" ]]; then
        details=$(get_file_details "$item")
        file_details+="${details}\n"
    fi
done

# Check if there are files to process
if [[ -z "$file_details" ]]; then
    echo "No files found in the current folder."
    exit 0
fi

# Display the file list
echo -e "Files detected:\n$file_details"

# Ask AI for grouping suggestions
echo "Requesting AI suggestions for grouping..."
ai_result=$(get_ai_grouping "$file_details")

# Display AI's grouping suggestions
echo -e "\nAI Grouping Suggestions:\n$ai_result\n"

# Check if AI response is empty or null
if [[ -z "$ai_result" || "$ai_result" == "null" ]]; then
    echo "AI response null. Exiting the program."
    exit 1
fi

# split the AI response into lines and process each line
while read -r line; do
    # Split the line on the first ' -> ' to separate the file name and folder name
    file_name=$(echo "$line" | cut -d' ' -f1- | sed 's/ ->.*//')  # Capture everything before ' ->'
    folder_name=$(echo "$line" | sed 's/.* -> //')  # Capture everything after ' ->'
    
    # Clean up leading and trailing quotes or unwanted spaces
    file_name=$(echo "$file_name" | sed 's/^"//;s/"$//')
    folder_name=$(echo "$folder_name" | sed 's/^"//;s/"$//')

    # Debugging output to see the result
    # echo "File: $file_name | Folder: $folder_name"

    # Skip if the folder name is empty
    if [[ -z "$folder_name" ]]; then
        echo "Skipping $file_name as no folder was suggested."
        continue
    fi

    # Skip if file name is tidyup.sh
    if [[ "$file_name" == "tidyup.sh" ]]; then
        echo "Skipping $file_name as it is the script file."
        continue
    fi

    # Create the folder if it doesn't exist
    folder_path="$CURRENT_FOLDER/$folder_name"
    if [[ ! -d "$folder_path" ]]; then
        echo "Creating folder: $folder_path"
        mkdir "$folder_path"
    fi

    # Move the file to the folder
    echo "Moving $file_name to $folder_path"
    mv "$CURRENT_FOLDER/$file_name" "$folder_path"
done <<< "$ai_result"

echo "File organization complete!"
