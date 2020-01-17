import json
import sys

input_arg = sys.argv[1]
# read json file
with open(input_arg, 'r') as myfile:
    data=myfile.read()

#parse file
result = json.loads(data)

afailedTestCases = []
aFailedTestCasesString = ''
failedtestCases = result['issues']['testFailureSummaries']['_values']

if len(failedtestCases) == 0:
    sys.stdout.write("")
    sys.exit("Couldn't find any failed test cases.")

for failedTestcase in failedtestCases:
    test = str(failedTestcase['testCaseName']['_value'])
    path = "<test_scheme_name>/" + test[:len(test)-2].replace(".","/")
    #afailedTestCases.append(path)
    aFailedTestCasesString += path+' '
    
sys.stdout.write(aFailedTestCasesString)
