# Code which works as interpretor. This one redirects the command to bash shell.
#! /bin/sh

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

if ! [ -x "$(command -v xcpretty)" ]; then
  echo 'Error: xcpretty is not installed.' >&2
  sudo gem install xcpretty
fi

path=$(pwd)
project_dir="$path"
project_name="<project_name>"
build_target_name="<build_target>"
test_scheme="<test_scheme>"
test_scheme_configuration="xctest"
test_destination="platform=iOS Simulator,name=iPhone 8 Plus,OS=12.1"
test_resultBundle_path="$path/ResultBundle.xcresult"

# Xcode Build Sysytem action names.
xcodebuild_action_build="build-for-testing"
xcodebuild_action_test="test-without-building"

# test report
test_report_name="${test_scheme}_test_report"

echo "----- 1. Show build settings of the project. -----"
xcodebuild -project $project_name.xcodeproj -target "${build_target_name}" -showBuildSettings

DERIVED_DATA_DIR="${project_dir}/Build"

echo "----- 2. Remove existing test result bundle from project directory. -----"
rm -rf ${project_dir}/ResultBundle.xcresult

# Generate xctestrun file.
echo "----- 3. Generating xctestrun file. -----"
xcodebuild ${xcodebuild_action_build} -project "$project_dir/$project_name.xcodeproj" -scheme "${test_scheme}" -configuration "${test_scheme_configuration}" -destination "${test_destination}" -derivedDataPath ${DERIVED_DATA_DIR} ONLY_ACTIVE_ARCH=YES CODE_SIGNING_REQUIRED=NO | xcpretty

# Start testing selected UIAutomation test cases.
echo "----- 4. Execute test on <test_scheme> with the generated testrunfile. -----"
xcodebuild ${xcodebuild_action_test} -xctestrun ${DERIVED_DATA_DIR}/Build/Products/<test_scheme>_iphonesimulator13.2-x86_64.xctestrun -destination "${test_destination}" -only-testing:"${test_scheme}/CollaborationTest/test01FirstLaunch" -resultBundlePath ResultBundle.xcresult | xcpretty

# Convert xcresult data into json.
echo "----- 5. Generate json file from xcresult report. -----"
xcrun xcresulttool get --path ${project_dir}/ResultBundle.xcresult --format json > ${project_dir}/test_report_name | xcpretty

# Get parsed results from python script.
echo "----- 6. Parse json report for failed test cases. -----"
failed_test_cases=$(python ${project_dir}/jsonParser.py "${project_dir}/test_report_name")
echo $failed_test_cases

# If no failed test cases, then exit the script execution.
if [ ! "$failed_test_cases" ];then
   echo "Hurray!! All the test cases have been passed. No need to re-run."
   exit 1
fi

echo "----- 7. Printing json content in test result. -----"
cat ${project_dir}/test_report_name

# Generates retry command to run all failed test cases one more time.
failed_test_cases_temp_list=""
generate_retry_command(){
   test_list=""
   for testCase in $1;
   do
     test_list+=" -only-testing:$testCase"
   done
   finalCmd="xcodebuild ${xcodebuild_action_test} -xctestrun ${DERIVED_DATA_DIR}/Build/Products/<test_scheme>_iphonesimulator13.2-x86_64.xctestrun -destination "\'"${test_destination}"\'" "${test_list}" -resultBundlePath ResultBundle_Retry1.xcresult | xcpretty"
   failed_test_cases_temp_list="$finalCmd"
   echo $failed_test_cases_temp_list
}

# Get re-run command, pass failed test cases list recieved from python as argument.
echo "----- 8. Generating re-run command for failed test cases. -----"
generate_retry_command $failed_test_cases


echo "----- 9. Remove existing test result bundle from project directory. -----"
rm -rf ${project_dir}/ResultBundle_Retry1.xcresult

# Evaluate the re-run command returned from generate method.
echo "----- 10. Evaluate the re-run command. -----"

eval $failed_test_cases_temp_list

# clear content for text file
> ${project_dir}/test_report_name

# Convert xcresult data into json.
echo "----- 11. Generate json file from xcresult report. -----"
xcrun xcresulttool get --path ${project_dir}/ResultBundle_Retry1.xcresult --format json > ${project_dir}/test_report_name | xcpretty

cat ${project_dir}/test_report_name
# Get parsed results from python script.
echo "----- 12. Parse json report for failed test cases. -----"
retry_failed_test_cases=$(python ${project_dir}/jsonParser.py "${project_dir}/test_report_name")
echo $retry_failed_test_cases
