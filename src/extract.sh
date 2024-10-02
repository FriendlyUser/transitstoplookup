#!/bin/bash

#!/bin/bash

# Base URL structure
BASE_URL="https://gtfs-static.translink.ca/gtfs/History/"
FILE_NAME="google_transit.zip"
PUBLIC_DIR="./public"
# Function to get the last Friday date
get_last_friday() {
    current_date=$(date +%Y-%m-%d)
    last_friday=$(date -d "last Friday" +%Y-%m-%d)
    echo $last_friday
}

# Starting date: last Friday
START_DATE=$(get_last_friday)

# First, check the last Friday
PREDICTED_URL="${BASE_URL}${START_DATE}/${FILE_NAME}"
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" $PREDICTED_URL)

if [ "$STATUS_CODE" -eq 200 ]; then
    echo "Valid URL found for last Friday: $PREDICTED_URL"
else
    echo "Last Friday URL not found: $PREDICTED_URL"

    # Loop through the next 7 days to predict future URLs
    for i in {1..7}
    do
        # Calculate the date by adding $i days to the START_DATE
        PREDICTED_DATE=$(date -I -d "$START_DATE + $i days")

        # Construct the full URL
        PREDICTED_URL="${BASE_URL}${PREDICTED_DATE}/${FILE_NAME}"

        # Check if the URL is accessible
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" $PREDICTED_URL)

        if [ "$STATUS_CODE" -eq 200 ]; then
            echo "Valid URL found: $PREDICTED_URL"
            break
        else
            echo "URL not found: $PREDICTED_URL"
        fi
    done
fi

# If no valid URL was found, exit the script
if [ "$STATUS_CODE" -ne 200 ]; then
    echo "No valid URL found for the last Friday or next 7 days."
    exit 1
fi

# Download the zip file
ZIP_FILE="google_transit.zip"
curl -o $ZIP_FILE $PREDICTED_URL

# Create public directory if it doesn't exist
mkdir -p $PUBLIC_DIR

# Unzip the contents to the public directory
unzip -o $ZIP_FILE -d $PUBLIC_DIR

# Cleanup the zip file
rm $ZIP_FILE

echo "GTFS files extracted to $PUBLIC_DIR"