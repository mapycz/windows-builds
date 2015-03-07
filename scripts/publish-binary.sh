#!/usr/bin/env bash
cwd=$(pwd)
set -e


PUBLISH_SDK=0
COMMIT_MESSAGE=$(git show -s --format=%B $TRAVIS_COMMIT | tr -d '\n')
echo $COMMIT_MESSAGE
if test "${COMMIT_MESSAGE#*'[publish binary]'}" != "$COMMIT_MESSAGE"
then
    echo "PUBLISHING mapnik SDK"
    PUBLISH_SDK=1
else
    echo "NOT publishing"
fi



sudo pip install awscli

gitsha="$1"
sleep=10
date_time=`date +%Y%m%d%H%M`
start_timestamp=`date +"%s"`
maxtimeout=2880
user_data="<powershell>
    ([ADSI]\"WinNT://./Administrator\").SetPassword(\"Diogenes1234\")
    [Environment]::SetEnvironmentVariable(\"PUBLISHMAPNIKSDK\", \"${PUBLISH_SDK}\", \"User\")
    [Environment]::SetEnvironmentVariable(\"AWS_ACCESS_KEY_ID\", \"${PUBLISH_KEY}\", \"User\")
    [Environment]::SetEnvironmentVariable(\"AWS_SECRET_ACCESS_KEY\", \"${PUBLISH_ACCESS}\", \"User\")
    Invoke-WebRequest https://mapnik.s3.amazonaws.com/dist/dev/windows-build-server/build.ps1 -OutFile Z:\\build.ps1
    & Z:\\build.ps1
    </powershell>
    <persist>true</persist>"

id=$(aws ec2 run-instances \
    --region eu-central-1 \
    --image-id ami-3690a22b \
    --count 1 \
    --instance-type c3.4xlarge \
    --user-data "$user_data" | jq -r '.Instances[0].InstanceId')

echo "Created instance: $id"

dns=$(aws ec2 describe-instances --instance-ids $id --region eu-central-1 --query "Reservations[0].Instances[0].PublicDnsName")
dns="${dns//\"/}"
echo "temporary windows build server: $dns/wbs"

aws ec2 create-tags --region eu-central-1 --resources $id --tags "Key=Name,Value=Temp-mapnik-windows-build-server-${TRAVIS_REPO_SLUG}-${TRAVIS_JOB_NUMBER}"
aws ec2 create-tags --region eu-central-1 --resources $id --tags "Key=GitSha,Value=$gitsha"

instance_status_stopped=$(aws ec2 describe-instances --region eu-central-1 --instance-id $id | jq -r '.Reservations[0].Instances[0].State.Name')
until [ "$instance_status_stopped" = "stopped" ]; do
    if [ `expr $(date "+%s") - $start_timestamp` -gt $maxtimeout ]; then
        echo "The instance has timed out. Terminating instance: $id"
        terminating_status=$(aws ec2 terminate-instances --region eu-central-1 --instance-ids $id | jq -r '.TerminatingInstances[0].CurrentState.Name')
        exit 1
    fi

    instance_status_stopped=$(aws ec2 describe-instances --region eu-central-1 --instance-id $id | jq -r '.Reservations[0].Instances[0].State.Name')
    echo "Instance stopping status eu-central-1 $id: $instance_status_stopped"

    sleep $sleep
done

terminating_status=$(aws ec2 terminate-instances --region eu-central-1 --instance-ids $id | jq -r '.TerminatingInstances[0].CurrentState.Name')
echo "Publish complete, terminating instance: $id"

exit 0
