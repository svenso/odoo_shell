using namespace System.Management.Automation
using namespace System.Reflection

Class TabComplete : Attribute {
    [string]$Source;
	[string]$SourceProperty;

    TabComplete([string]$Source, [string]$SourceProperty)
    {
        $this.Source = $Source
		$this.SourceProperty = $SourceProperty
    }
}

$typemap = @{
	"integer"="int";
	"boolean"="bool";
	"many2one"="object";
	"many2many"="object[]";
	"one2many"="object";
	"binary"="string";
	"char"="string";
	"float"="float";
	"text"="string";
	"date"="datetime";
	"datetime"="datetime";
	"selection"="object";
	"size"="int";
	"on_delete"="object";
	"relation"="object";
}

function Set-OdooConnectionInfo {
	param(
		[parameter(Mandatory=$true)][string]$Uri
		,[parameter(Mandatory=$true)][string]$User
		,[parameter(Mandatory=$true)][string]$Token
		,[parameter(Mandatory=$true)][string]$Database
		,[switch]$NotDefault
		,[switch]$SkipCmdletGeneration
		,[string[]]$Models = @("product.product","product.template","stock.change.product.qty")
	)
	$tmp = @{'Uri'=$Uri;'Token'=$Token;'Database'=$Database;'User'=$User;'UserId'=$User};

	$result = _fOdooInvokeRest -Connection $tmp -Method "login" -Service "common"
	$tmp["UserId"] = $result;

	if ($NotDefault.IsPresent ){
		$tmp;
	}else {
		$global:odooconnection = $tmp;
	}
	
	if ($SkipCmdletGeneration.IsPresent -eq $false){
		_fOdooGenerateCmdlets -Models $Models
	}
}


function _fOdooGenerateCmdlets {
	param(
		[string[]]$Models
	)
	
	_fOdooGenerateMethods -Models $Models
	
}

function _fOdooUpperFirst {
	param(
		[parameter(Position=0)]$text
	)
	if ($text -eq $null){
		return "";
	}
	[char]::ToUpper($text[0])+$text.Substring(1);
}

function _fOdooInvokeRest {
	param(
		[string]$Method,
		[string]$Service = "object",
		[string]$Model,
		[string]$Action,
		[Array]$Parameters,
		$Connection = $global:odooconnection
	)
	$Connection = $Connection ?? $global:odooconnection
	
	$id = Get-Random -Minimum 100000000 -Maximum 999999999
	$argsTmp = @(
				$Connection.Database,
				$Connection.UserId,
				$Connection.Token,
				$Model,
				$Action
			) + $Parameters;
			
	
	$args = [System.Collections.ArrayList]@();
	[array]::Reverse($argsTmp)
	foreach ($arg in $argsTmp){
		if ($arg -eq '' -or $arg -eq $null){
			continue;
		}
		$args.Insert(0, $arg);
	}

	$call = @{
		"id"=$id;
		"jsonrpc"="2.0";
		"method"="call";
		"params"=@{
			"args"=$args;
			"method"=$Method;
			"service"=$Service
		}
	}
	
	$contenttype = "application/json; charset=utf-8";
	$result = Invoke-RestMethod -Method Post -UseBasicParsing -Uri "$($Connection.Uri)/jsonrpc" -ContentType $contenttype -Body (ConvertTo-Json $call -Depth 100)
	if ($result.error -ne $null){
		 throw "API responded with error: $(ConvertTo-Json $result.error)"
	}
	$result.result;
}


function _fOdooGetSearchItems{
	param(
		[string]$Model
		,[string[]]$Fields
		,[string[]]$Search
		,$Connection
	)
	$ifields = @{};
	foreach ($field in $Fields){
		$ifields.Add($field,@());
	}
	$filter = @()
	if ($Search -ne $null){
		$filter = @(,$Search)
	}
	$result = _fOdooInvokeRest -Connection $Connection -Method execute -Model $Model -Action search_read -Parameters $filter,$ifields
	$result
}

function _fOdooGetItem{
	param(
		[string]$Model
		,[int[]]$Ids
		,[string[]]$Fields
		,$Connection
	)
	$ifields = @{};
	foreach ($field in $Fields){
		$ifields.Add($field,@());
	}
	$result = _fOdooInvokeRest -Connection $Connection -Method execute -Model $Model -Action read -Parameters $Ids,$ifields
	$result
}


function _fOdooSetItem{
	param(
		$id
		,[string]$Model
		,[Hashtable]$Data
		,$Connection
	)
	$result = _fOdooInvokeRest -Connection $Connection -Method execute -Model $Model -Action 'write' -Parameters @($id),$Data
	$result
}

function _fOdooGetModel{
	param(
		[string]$Model,
		$Connection
	)
	
	$result = _fOdooInvokeRest -Connection $Connection -Method execute -Model $Model -Action fields_get 
	$result
}

function _fOdooAddItem{
	param(
		[string]$Model
		,[Hashtable]$Data
		,$Connection
	)
	$result = _fOdooInvokeRest -Connection $Connection -Method execute -Model $Model -Action 'create' -Parameters $Data
	$result
}

function _fOdooDeleteItem{
	param(
		[int[]]$Id
		,[string]$Model
		,$Connection
	)
	$result = _fOdooInvokeRest -Connection $Connection -Method execute -Model $Model -Action 'unlink' -Parameters $Id
	$result
}


function _fOdooGenerateMethod {
	param(
		[string]$Model,
		$Connection
	)
	
	
	$niceName = ($Model.Split('.') | %{ _fOdooUpperFirst $_}) -join ''
	
	$actions = Get-Content -Raw "actions.json" | ConvertFrom-Json
	foreach ($action in $actions.$Model){
		$niceAction = ($action.Split('_') | %{ _fOdooUpperFirst $_}) -join '';
		$actionMethod = @"
			function global:Invoke-Odoo$($niceName)$($niceAction) {
				[CmdletBinding()]
				param(
					[parameter(Position = 0)][int[]]`$TargetId
					,`$Connection
				)
				
				`$result = _fOdooInvokeRest -Connection `$Connection -Method execute -Model $Model -Action $action -Parameters `$TargetId
				`$result
			}
"@;
		$block = [ScriptBlock]::Create($actionMethod);
		. $block
	}
	
	$fields = _fOdooGetModel -Connection $Connection -Model $Model
	foreach ($prop in $fields.PSObject.Properties.Name){
		if (!$fields.$prop.readonly){
			$fields.$prop | Add-Member -MemberType NoteProperty -Name nice_name -Value (($prop.Trim('_').Split('_') | %{ _fOdooUpperFirst $_}) -join '')
		}
	}
	$map = @"
`$map = @{"dummy"="dummy"
	$(foreach ($prop in $fields.PSObject.Properties.Name){ 
		if (!$fields.$prop.readonly) { 
			";""$($fields.$prop.nice_name)""= ""$($prop)""`r`n"
		}
	})
};	
`$mapReverse = @{"dummy"="dummy"
	$(foreach ($prop in $fields.PSObject.Properties.Name){ 
		if (!$fields.$prop.readonly) { 
			";""$($prop)""=""$($fields.$prop.nice_name)""`r`n"
		}
	})
};	
"@;

	$enumFields = @"
	enum Enum$($niceName) {
		$(foreach ($prop in $fields.PSObject.Properties.Name){ 
			if (!$fields.$prop.readonly) { 
				"$($fields.$prop.nice_name)`r`n"
			}
		})
	}
"@;
	$block = [ScriptBlock]::Create($enumFields);
	. $block
	
	$getMethod = @"
	function global:Get-Odoo$($niceName) {
		[CmdletBinding(SupportsPaging = `$true, DefaultParameterSetName = 'GetBySearch')]
		param(
			[TabComplete('Get-Odoo$($niceName) -Search `$wordToComplete', "id")][parameter(Position = 0, ParameterSetName='GetById')][int[]]`$TargetId
			,[parameter(Position = 0, ParameterSetName='GetBySearch')][string[]]`$Search
			,[parameter()][Enum$($niceName)[]]`$Fields
			,[parameter()][string[]]`$FieldsFull
			,`$Connection
		)
		
		$map
			
		if (`$PsCmdlet.ParameterSetName -eq 'GetById') {
			_fOdooGetItem -Connection `$Connection -Model $Model -Ids `$TargetId -Fields (`$Fields ?? `$FieldsFull ?? @() | %{ `$map[`$_.ToString()] ?? `$_ })
		} else {
			_fOdooGetSearchItems -Connection `$Connection -Model $Model	-Fields (`$Fields ?? `$FieldsFull ?? @() | %{ `$map[`$_.ToString()] ?? `$_ }) -Search `$Search
		}
		
	}
"@;

	
	$setMethod = @"
	function global:Set-Odoo$($niceName) {
		[CmdletBinding()]
		param(
			[parameter(Position = 0)][int]`$TargetId
			$(foreach ($prop in $fields.PSObject.Properties.Name){ if (!$fields.$prop.readonly) { ", [$($typemap[$fields.$prop.type] ?? $fields.$prop.type)]`$$($fields.$prop.nice_name)`r`n" }})
			,[parameter()][hashtable]`$AdditionalFields
			,`$Connection
		)
		process {
			$map
			
			`$ops = [Hashtable]@{}
			foreach (`$key in `$PSBoundParameters.Keys){
				if (`$map[`$key] -ne `$null) {
					`$ops.Add(`$map[`$key], `$PSBoundParameters[`$key]);
				}
			}
			foreach (`$key in `$AdditionalFields.Keys) {
				`$ops.Add(`$key, `$AdditionalFields[`$key]);
			}
			
			_fOdooSetItem -Connection `$Connection -Id `$TargetId -Model $Model -Data `$ops
		}
	}
	
	function global:Add-Odoo$($niceName) {
		[CmdletBinding()]
		param(
			[parameter(DontShow)]`$dummy
			$(foreach ($prop in $fields.PSObject.Properties.Name){ if (!$fields.$prop.readonly) { ", `$$($fields.$prop.nice_name)`r`n" }})
			,[parameter()][hashtable]`$AdditionalFields
			,`$Connection
		)
		process {
			$map
			
			`$ops = [Hashtable]@{}
			foreach (`$key in `$PSBoundParameters.Keys){
				if (`$map[`$key] -ne `$null) {
					`$ops.Add(`$map[`$key], `$PSBoundParameters[`$key]);
				}
			}
			foreach (`$key in `$AdditionalFields.Keys) {
				`$ops.Add(`$key, `$AdditionalFields[`$key]);
			}
			_fOdooAddItem -Connection `$Connection -Model $Model -Data `$ops
		}
	}
	
	function global:Remove-Odoo$($niceName) {
		[CmdletBinding()]
		param(
			[parameter(Position = 0)][string]`$TargetId
			,`$Connection
		)
		process {
			_fOdooDeleteItem -Connection `$Connection -Id `$TargetId -Model $Model
		}
	}
	
"@;
	
	$block = [ScriptBlock]::Create($getMethod);
	. $block
	$block = [ScriptBlock]::Create($setMethod);
	. $block
}


function _fOdooGenerateMethods {
	param(
		$Models
		,$Connection
	)
	
	if ($Models -eq $null){
		$Models = _fOdooGetSearchItems -Model ir.model -Fields name,model | select -expandproperty model
	}
	
	foreach ($model in $models){
		if ($model.Contains(".")){
			_fOdooGenerateMethod -Connection $Connection -Model $model
		}
	}
}
























