netsh interface ip set address name="Ethernet" static 192.168.1.200 255.255.255.0 192.168.1.1 1
netsh interface ip set dnsservers name="Ethernet" source=static address=
netsh interface ip add dns "Ethernet" 192.168.1.1 index=1

(gwmi Win32_cdromdrive).drive | %{$a = mountvol $_ /l;mountvol $_ /d;$a = $a.Trim();mountvol z: $a} 

diskpart

select disk 1
online disk
attributes disk clear readonly
create partition primary
assign letter=F
exit

echo y | format F: /FS:NTFS /Q

function Set-DriveLabel($letter='C:', $label='ISOC-GDC0_C') {
if (!(Test-Path $letter)) {
Throw "Drive $letter does not exist."
}
$instance = ([wmi]"Win32_LogicalDisk='$letter'")
$instance.VolumeName = $label
$instance.Put()
}
set-drivelabel C: 'TUS-DC2_C'
set-drivelabel F: 'TUS-DC2_F'

rename-computer -newname TUS-DC2 -restart


Install-WindowsFeature -name AD-Domain-Services,GPMC,DNS -IncludeManagementTools -Restart
$restore = Read-Host 'SafeModeAdministratorPassword?' -AsSecureString
import-module ADDSDeployment
install-addsforest -DomainName aaco.local -DomainNetbiosName AACO -LogPath f:\NTDS -SysvolPath f:\SYSVOL -DatabasePath f:\NTDS -DomainMode WinThreshold -ForestMode WinThreshold -SafeModeAdministratorPassword $restore -force

#ous, groups
New-ADOrganizationalUnit -Name UserObjects
New-ADOrganizationalUnit -Name ComputerObjects

#Move CN=Computers to OU=ComputerObjects
Get-ADComputer -Filter * -SearchBase "CN=Computers,DC=aaco,DC=local" | Move-ADObject -TargetPath "OU=ComputerObjects,DC=aaco,DC=local"

$restore = Read-Host 'aaco.user Password?' -AsSecureString
New-ADUser -Name aaco.user -AccountPassword $restore -ChangePasswordAtLogon $false -DisplayName "aaco user" -EmailAddress aaco.user@aaco.local -Enabled $true -GivenName aaco -Path "OU=UserObjects,DC=aaco,DC=local" -SamAccountName aaco.user -Surname user -UserPrincipalName aaco.user@aaco.local

#DNSCMD
dnscmd TUS-DC2 /zoneadd aaco.com /DSPrimary
dnscmd TUS-DC2 /recordadd aaco.com pki A 192.168.1.207
