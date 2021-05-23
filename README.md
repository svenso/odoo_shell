# Odoo Shell

This simple powershell module dynamically generates cmdlets for managing odoo 14.

## How to use
Requires Powershell Core >= 7.1.x

````
Import-Module .\OdooShell.psm1
Set-OdooConnectionInfo -Uri https://my.odooo.instance -User user@user.com -Token xxxxAPI-TOKENxxxx -Database dbname
````

This will import all Models. If you just want to import some models use:
````
Import-Module .\OdooShell.psm1
Set-OdooConnectionInfo -Uri https://my.odooo.instance -User user@user.com -Token xxxxAPI-TOKENxxxx -Database dbname -Models "product.product","product.template"
````