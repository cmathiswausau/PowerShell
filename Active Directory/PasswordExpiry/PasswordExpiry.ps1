#Requires -Modules ActiveDirectory
<#	
	 ===========================================================================
	 Created on:   	3/27/2018 7:37 PM
     Modified on:   04/25/22 2:57 PM
     Modified by:   Chris Mathis - The Dirks Group
	 Created by:   	Bradley Wyatt
	 Version: 	    1.0.5.CSM
	 Notes:
        Run the script manually first as it will ask for credentials to send email and then safely store them for future use.
        If there is a problem with the credentials delete C:\Automation\PasswordExpiry\EmailExpiry.cred
	 ===========================================================================
		This script will send an e-mail notification to users where their password is set to expire soon. It includes step by step directions for them to 
		change it on their own.

		It will look for the users e-mail address in the emailaddress attribute and if it's empty it will use the proxyaddress attribute as a fail back. 

		The script will log each run at $DirPath\log.txt
     ===========================================================================
        The Settings.xml file should be modified as follows.

        The variables you should change are the SMTP Host, From Email, CustomerName and Expireindays.
     ===========================================================================
        The following is only needed if the password policy is not using the Password Settings Container via ADAC

        Optionally change the pwdchar, pastPwd and passComplex to adjust what parameters are for the client
 
        If the customer wants to get the email for failure to email change the FailureEmail
#>
$DirPath = "C:\Automation\PasswordExpiry"
$SettingsObj = ($DirPath + "\" + "settings.xml")
$SettingsPathCheck = Test-Path -Path $SettingsObj
If (!($SettingsPathCheck))
{
	Try
	{
        [System.Windows.MessageBox]::Show('Please move settings file to $SettingsObj')
        Write-Output "Please move settings file to $SettingsObj"
        break 1
	}
	Catch
	{
		$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
	}
}

[xml]$vars=Get-Content -Path $SettingsObj

foreach ($setting in $vars.PasswordChange.Variables.All.Split(","))
    {
    write-output $setting
    Set-Variable -Name $setting -Value $vars.PasswordChange.settings.$setting
    Get-Variable -Name $setting -ValueOnly
    }
foreach ($setting in $vars.PasswordChange.Variables.Boolian.Split(","))
    {
    if ($vars.PasswordChange.settings.$setting -eq "True")
        {
            Set-Variable -Name $setting -Value $true
        }
    else
        {
            Set-Variable -Name $setting -Value $false
        }
    write-output $setting
    Get-Variable -Name $setting -ValueOnly
}

$complexityscript = ""
$Date = Get-Date
#CredObj path
$CredObj = ($DirPath + "\" + "EmailExpiry.cred")
#Check if CredObj is present
$CredObjCheck = Test-Path -Path $CredObj
If (!($CredObjCheck))
{
	"$Date - INFO: creating cred object" | Out-File ($DirPath + "\" + "Log.txt") -Append
	#If not present get office 365 cred to save and store
	$Credential = Get-Credential -Message "Please enter your Office 365 credential that you will use to send e-mail from $FromEmail. If you are not using the account $FromEmail make sure this account has 'Send As' rights on $FromEmail."
	#Export cred obj
	$Credential | Export-CliXml -Path $CredObj
}

Write-Host "Importing Cred object..." -ForegroundColor Yellow
$Cred = (Import-CliXml -Path $CredObj)
"$Date - INFO: Getting users" | Out-File ($DirPath + "\" + "Log.txt") -Append
IF (!($TestingMode))
{
$users = Get-Aduser -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress  -filter { (Enabled -eq 'True') -and (PasswordNeverExpires -eq 'False') } | Where-Object { $_.PasswordExpired -eq $False -or $_.PasswordExpired -eq $null } 
}
else 
{
$users = Get-Aduser -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress  -filter { (Enabled -eq 'True') -and (PasswordNeverExpires -eq 'False') } | Where-Object { $_.PasswordExpired -eq $False } | Where-Object { $_.EmailAddress -eq $testuseraccountemail }
$expireindays=365
}

$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

# Clear failed users variable
$FailedUsers = ""
# Process Each User for Password Expiry
foreach ($user in $users)
{
	$Name = (Get-ADUser $user | ForEach-Object { $_.Name })
	Write-Host "Working on $Name..." -ForegroundColor White
	Write-Host "Getting e-mail address for $Name..." -ForegroundColor Yellow
    $Username = $user.SamAccountName
	$emailaddress = $user.emailaddress
	#Get Password last set date
	$passwordSetDate = (Get-ADUser $user -properties * | ForEach-Object { $_.PasswordLastSet })
	#Check for Fine Grained Passwords
	$PasswordPol = (Get-ADUserResultantPasswordPolicy $user)
	if (($PasswordPol) -ne $null)
	{
		$maxPasswordAge = ($PasswordPol).MaxPasswordAge
        $pwdchar = ($PasswordPol).MinPasswordLength
        $pastPwd = ($PasswordPol).PasswordHistoryCount
        $passComplex = ($PasswordPol).ComplexityEnabled
	}
	$expireson = $passwordsetdate + $maxPasswordAge
	$today = (get-date)
	#Gets the count on how many days until the password expires and stores it in the $daystoexpire var
	$daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days
	If (!($emailaddress))
	{
		Write-Host "$Name has no E-Mail address listed, looking at their proxyaddresses attribute..." -ForegroundColor Red
		Try
		{
			$emailaddress = (Get-ADUser $user -Properties proxyaddresses | Select-Object -ExpandProperty proxyaddresses | Where-Object { $_ -cmatch '^SMTP' }).Trim("SMTP:")
		}
		Catch
		{
			$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
		}
		If (!($emailaddress))
		{
			Write-Host "$Name has no email addresses to send an e-mail to!" -ForegroundColor Red
			#Don't continue on as we can't email $Null, but if there is an e-mail found it will email that address
			"$Date - WARNING: No email found for $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
            $FailedUsers = $FailedUsers +
@"
            <tr>
                <td width=150 valign=top style='width:150pt;border:solid black 1.0pt;background:#white;padding:0in 5.4pt 0in 5.4pt'>
                    <p style='margin-bottom:0in;line-height:normal'><o:p>$username</o:p></p>
                </td>
                <td width=150 valign=top style='width:150pt;border:solid black 1.0pt;background:#white;padding:0in 5.4pt 0in 5.4pt'>
                    <p style='margin-bottom:0in;line-height:normal;'><o:p>$Name</o:p></p>
                </td>
                <td width=150 valign=top style='width:150pt;border:solid black 1.0pt;background:#white;padding:0in 5.4pt 0in 5.4pt'>
                    <p style='margin-bottom:0in;line-height:normal;'><o:p>$daystoexpire</o:p></p>
                </td>
            </tr>
"@
            #Write-Output $FailedUsers
		}
		
	}

	
	If (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays) -and ($emailaddress))
	{
		"$Date - INFO: Sending expiry notice email to $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
		Write-Host "Sending Password expiry email to $name" -ForegroundColor Yellow
		
		$SmtpClient = new-object system.net.mail.smtpClient
		$MailMessage = New-Object system.net.mail.mailmessage
		$smtpClient.Port = $smtpport
		#Who is the e-mail sent from
		$mailmessage.From = $FromEmail
		#SMTP server to send email
		$SmtpClient.Host = $SMTPHost
		#SMTP SSL
		$SMTPClient.EnableSsl = $EnableSslEmail
		#SMTP credentials
		$SMTPClient.Credentials = $cred
		#Send e-mail to the users email
		$mailmessage.To.add("$emailaddress")
		#Email subject 
		$mailmessage.Subject = "Your password at $CustomerName will expire in $daystoexpire days"
		#Notification email on delivery / failure
	 $MailMessage.DeliveryNotificationOptions = ("onSuccess", "onFailure")
		#Send e-mail with high priority
		$MailMessage.Priority = "High"
        $MailMessage.isBodyHtml = $true
        if ($passComplex -eq $true){
       $complexityscript = $ExecutionContext.InvokeCommand.ExpandString($vars.PasswordChange.Message.Complexity.p1.'#cdata-section')
}

        $mailmessage.Body = $ExecutionContext.InvokeCommand.ExpandString($vars.PasswordChange.Message.Main.p1.'#cdata-section') + "
" + $complexityscript + "
        " + $ExecutionContext.InvokeCommand.ExpandString($vars.PasswordChange.Message.Main.p2.'#cdata-section')

		Write-Host "Sending E-mail to $emailaddress..." -ForegroundColor Green
		Try
		{
            $smtpclient.Send($mailmessage)
            Write-Host "Sent!!" -ForegroundColor Green
            Sleep $Delay            
		}
		Catch
		{
			$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
            Write-Host "Failed!!" -ForegroundColor Red

		}
	}
	Else
	{
		"$Date - INFO: Password for $Name not expiring for $daystoexpire days" | Out-File ($DirPath + "\" + "Log.txt") -Append
		Write-Host "Password for $Name does not expire for $daystoexpire days" -ForegroundColor White
	}

}
if (!($FailedUsers) -eq ""){
    $emailaddress = $FailureEmail
    $SmtpClient = new-object system.net.mail.smtpClient
	$MailMessage = New-Object system.net.mail.mailmessage
	$smtpClient.Port = $smtpport
	#Who is the e-mail sent from
	$mailmessage.From = $FromEmail
	#SMTP server to send email
	$SmtpClient.Host = $SMTPHost
	#SMTP SSL
	$SMTPClient.EnableSsl = $EnableSslEmail
	#SMTP credentials
	$SMTPClient.Credentials = $cred
	#Send e-mail to the users email
	$mailmessage.To.add("$emailaddress")
	#Email subject
	$mailmessage.Subject = "$CustomerName`: Password Email Failures"
	#Notification email on delivery / failure
	$MailMessage.DeliveryNotificationOptions = ("onSuccess", "onFailure")
	#Send e-mail with high priority
	$MailMessage.Priority = "High"
    $MailMessage.isBodyHtml = $true
    $mailmessage.Body = $ExecutionContext.InvokeCommand.ExpandString($vars.PasswordChange.Message.FailedUsers.p1.'#cdata-section') + $FailedUsers + $ExecutionContext.InvokeCommand.ExpandString($vars.PasswordChange.Message.FailedUsers.p1.'#cdata-section')

		Write-Host "Sending E-mail to $emailaddress..." -ForegroundColor Green
		Try
		{
            $smtpclient.Send($mailmessage)
            Write-Host "Sent!!" -ForegroundColor Green
            
		}
		Catch
		{
			$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
            Write-Host "Failed!!" -ForegroundColor Red

		}
}