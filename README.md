# Odoo Shell

This simple powershell module dynamically generates cmdlets for managing odoo 14.

## How to use
Requires Powershell Core >= 7.1.x

````
Import-Module .\OdooShell.psm1
Set-OdooConnectionInfo -Uri https://my.odooo.instance -User user@user.com -Token xxxxAPI-TOKENxxxx -Database dbname -Models $null
````

This will import all Models. If you just want to import some models use:
````
Import-Module .\OdooShell.psm1
Set-OdooConnectionInfo -Uri https://my.odooo.instance -User user@user.com -Token xxxxAPI-TOKENxxxx -Database dbname -Models "product.product","product.template"
````

Get all items
````
Get-OdooProductProduct -Fields name,barcode
````

Search items
````
Get-OdooProductProduct -Fields name,barcode -Search name,'=',"Blabla"
````

Get By ID:
````
Get-OdooProductProduct -TargetId 784
````

Update item 
````
Set-OdooProductProduct -TargetId 784 -Price 12.20
````

Add item:
````
Add-OdooProductProduct -Price 10 -Name "TestProduct"
````

Delete item:
````
Remove-OdooProductProduct -TargetId 788
````

Calling a model specific method:
````
Invoke-OdooStockChangeProductQtyChangeProductQty -TargetId 1234
````



