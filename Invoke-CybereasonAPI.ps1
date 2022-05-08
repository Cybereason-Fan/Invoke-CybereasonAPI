Function global:Invoke-CybereasonAPI {
    <#
.SYNOPSIS
Invokes an on-premises Cybereason API
.DESCRIPTION
A framework function to invoke the Cybereason API. Use this to build other tools on or just to experiment with the API in a convenient way.
.PARAMETER server_fqdn
Required string - This is the fully qualified domain name of the Cybereason console. There is no error-checking on this. Make sure you have it correct. You should be able to ping this hostname.
.PARAMETER session_id
Required String - This is the 32-character string (session id) that you received when you authenticated to the console
.PARAMETER method
Required String - Must be one of four (GET, POST, PUT, DELETE)
.PARAMETER command
Required String - Must begin with a forward slash (e.g. /version)
.PARAMETER body
Optional Hashtable - Make sure this is a valid payload :)
.PARAMETER DebugMode
Optional Switch that will verbosely display the parameters that are sent to Invoke-WebRequest (good for troubleshooting)
.EXAMPLE
example missing
.LINK
https://git.dhl.com/miksimps/Invoke-CybereasonAPI
#>

    Param(
        [OutputType([PSCustomObject])]
        [Parameter(Mandatory = $true)]
        [string]$server_fqdn,
        [Parameter(Mandatory = $true)]
        [string]$session_id,        
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$method,
        [Parameter(Mandatory = $true)]
        [string]$command,
        [Parameter(Mandatory = $false)]
        [hashtable]$body,
        [Parameter(Mandatory = $false)]
        [switch]$DebugMode
    )
    [int32]$ps_version_major = $PSVersionTable.PSVersion.Major
    If( $null -eq (Get-Module -Name Microsoft.PowerShell.Utility) )
    {
    	Import-Module Microsoft.Powershell.Utility
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [string]$regex_jsessionid = '^[0-9A-F]{32}$'
    [string]$api_url = "https://$server_fqdn/rest"
    [string]$command_url = ($api_url + $command)
    [string]$server_name = $server_fqdn -replace 'http[s]{0,}://'
    If ( $session_id -cnotmatch $regex_jsessionid ) {
        Write-Host "Error: The session id must be a case-sensitive 32 character long string of 0-9 and A-F."
        Exit
    }
    If( $command -notlike '/*')
    {
        Write-Host "Error: The command must begin with a forward slash (e.g. /sensors/query)"
    }
    $Error.Clear()
    Try
    {
        [Microsoft.PowerShell.Commands.WebRequestSession]$web_session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    }
    Catch
    {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: New-Object failed to create a web request session object due to [$error_message]"
        Return
    }
    $Error.Clear()
    Try {
        $cookie = New-Object System.Net.Cookie 
        $cookie.Name = 'JSESSIONID'
        $cookie.Value = $session_id
        $cookie.Domain = $server_name
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: New-Object failed to create a cookie object due to [$error_message]"
        Return
    }
    $Error.Clear()
    Try {
        $web_session.Cookies.Add($cookie)
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: Failed to add the cookie object to the web request session object due to [$error_message]"
        Return
    }
    [hashtable]$parameters = @{}
    $parameters.Add('Uri', $command_url)
    $parameters.Add('Method', $method)
    $parameters.Add('ContentType', 'application/json')
    $parameters.Add('WebSession', $web_session)
    If( $null -ne $body)
    {
        [string]$body_json = ConvertTo-Json -InputObject $body -Compress -Depth 10
        $parameters.Add('Body', $body_json)
    }
    If ( $DebugMode -eq $true) {
        [string]$parameters_display = $parameters | ConvertTo-Json -Compress -Depth 4
        Write-Host "Debug: Sending parameters to Invoke-WebRequest $parameters_display"
    }
    $ProgressPreference = 'SilentlyContinue'
    $Error.Clear()
    Try {
        If ( $ps_version_major -eq 5 ) {
            [Microsoft.PowerShell.Commands.HtmlWebResponseObject]$response = Invoke-WebRequest @parameters
        }
        ElseIf ( $ps_version_major -ge 7 ) {
            [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]$response = Invoke-WebRequest @parameters
        }
        Else {
            Write-host "Error: The version of PowerShell could not be determined"
            Return
        }  
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: Invoke-WebRequest failed due to [$error_message]"
        Return
    }
    If ( $response.StatusCode -isnot [int]) {
        Write-Host "Error: Somehow there was no numerical response code"
        Return
    }
    [int]$response_statuscode = $response.StatusCode
    If ( $response_statuscode -ne 200) {
        Write-Host "Error: Received numerical status code [$response_statuscode] instead of 200 'OK'. Please look into this."
        Return
    }
    $Error.Clear()
    Try {    
        [PSCustomObject]$response_content = $response.Content | ConvertFrom-Json
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: ConvertFrom-Json failed due to [$error_message] [$response]"
        Return
    }
    Return $response_content
}