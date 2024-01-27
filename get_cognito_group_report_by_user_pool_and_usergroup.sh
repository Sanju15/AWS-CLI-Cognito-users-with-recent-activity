#!/bin/bash

# Display User pools as options and get user's choice
echo "Select an option:"
echo "1. Prod"
echo "2. UAT"
read -p "Enter # of the user pool (1/2): " Environment

if [ "$Environment" == "1" ]; then
    USER_POOL_ID="us-east-2_1WQPCDzKB"
    ENV=PROD
elif [ "$Environment" == "2" ]; then
    USER_POOL_ID="us-east-2_o0QahMhz8"
    ENV=UAT
else
    echo "Invalid choice. Exiting the script."
fi

# Get the list of group names in selected user pool
group_names=$(aws cognito-idp list-groups --user-pool-id $USER_POOL_ID --query "Groups[].GroupName" --output text)

# Display menu options for group selection
echo "Select a group:"
i=1
for group in $group_names; do
    echo "$group"
    ((i++))
done

# Get the group id
read -p "Enter the desired group name from the list: " GROUP_NAME
echo $GROUP_NAME
# Get the group name
aws cognito-idp list-users-in-group --user-pool-id $USER_POOL_ID --group-name $GROUP_NAME --query "Users[].Attributes[?Name=='email'].Value" --output text > $ENV-$GROUP_NAME-cognito_users.txt
echo "List of users in group '$ENV-$GROUP_NAME' saved to '$ENV-$GROUP_NAME-cognito_users.txt'"

# Create a text file to store the events
echo "Email,RecentEventType,Last Login Date[AEST]" > $ENV-$GROUP_NAME-user_recent_auth_activities.txt

# Read user emails from the created text file
while IFS= read -r email

do

    echo "Getting auth events for user: $email"
    events=$(aws cognito-idp admin-list-user-auth-events --user-pool-id $USER_POOL_ID --username "$email")
    
    # Reverse the order(most recent first)
    reversed_events=$(echo "$events" | jq '.AuthEvents')

    # Parse the most recent event
    most_recent_event=$(echo "$reversed_events" | jq -r '.[0]')

    if [ -n "$most_recent_event" ]; then
        event_type=$(echo "$most_recent_event" | jq -r '.EventType')
        timestamp=$(echo "$most_recent_event" | jq -r '.CreationDate')

        if [ -n "$timestamp" ] && [ "$timestamp" != "null" ]; then
            formatted_timestamp=$(TZ=Australia/Sydney date -d "@$timestamp" +"%Y-%m-%d %H:%M:%S")

            echo "$email,$event_type,$formatted_timestamp" >> $ENV-$GROUP_NAME-user_recent_auth_activities.txt
        else
            echo "Timestamp for user $email is not valid."
            echo "$email,null,null" >> $ENV-$GROUP_NAME-user_recent_auth_activities.txt
        fi
    else
        echo "No auth events found for user: $email"
    fi

done < $ENV-$GROUP_NAME-cognito_users.txt

echo "Email,RecentEventType,Last Login Date(AEST) saved to '$ENV-$GROUP_NAME-user_recent_auth_activities.txt'"

echo "ID,Email,RecentEventType,Last Login Date(AEST)" > $ENV-$GROUP_NAME-user_recent_auth_activities.csv

# Convert the text file to CSV format
id_counter=1

cat $ENV-$GROUP_NAME-user_recent_auth_activities.txt | while IFS=, read -r email event_type formatted_timestamp; do
    echo "$id_counter,\"$email\",\"$event_type\",\"$formatted_timestamp\"" >> $ENV-$GROUP_NAME-user_recent_auth_activities.csv
    ((id_counter++))
done

echo "CSV export saved to '$ENV-$GROUP_NAME-user_recent_auth_activities.csv'"


