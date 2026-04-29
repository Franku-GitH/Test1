
#Connect-MgGraph -Scopes "Group.ReadWrite.All"

# ID skupiny lze napr. zjistit v Entra ID, ve vlastnostech skupiny
$groupId = "c94722af-4b86-43fe-b8f6-5afdef961e93"

Write-host "Zpracovavam skupinu nasledujici skupinu: " -ForegroundColor Green
(Get-MgGroup -GroupId $groupId).DisplayName

# Kontrola pred zmenou
#$setting = Get-MgGroupSetting -GroupId $groupId
#$setting.values


# Nastaveni parametru pro zmenu
$params = @{
  values = @(
    @{
      name  = "AllowToAddGuests"
      value = "True"
    }
  )
}

Update-MgGroupSetting -GroupId $groupId -GroupSettingId $setting.Id -BodyParameter $params

Write-host "Provadim kontrolu skupiny a jejiho nastaveni po zmene: " -ForegroundColor Green
# Nasledna kontrola po zmene
$setting = Get-MgGroupSetting -GroupId $groupId
$setting.values