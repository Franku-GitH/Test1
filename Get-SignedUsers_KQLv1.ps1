let SuccessfulLogins =
SigninLogs
| where ResultType == 0
| summarize FirstLogin = min(TimeGenerated) by UserId, UserPrincipalName;

SuccessfulLogins
| extend State = "Signed"
| project UserPrincipalName, State, FirstLogin

union (
    SigninLogs
    | summarize by UserId, UserPrincipalName
    | join kind=anti (SuccessfulLogins) on UserId
    | extend State = "NotSigned", FirstLogin = datetime(null)
    | project UserPrincipalName, State, FirstLogin
)
| order by State asc