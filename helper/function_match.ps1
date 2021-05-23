param($GitDirectory)
$actions = @{};
get-childitem -Recurse *.py -Path $GitDirectory 
	| ?{$_.FullName -notlike "*test*"} 
	| ?{ $content = get-content $_.FullName; $content -match  "^class .*\(models\..*\)"} 
	| %{ 
		
		$content = get-content $_.FullName -Raw;  
		$nameMatch = [regex]::Match($content,'_name = "(.*?)"');
		if ($nameMatch.Success){
			$name = $nameMatch.Groups[1].Value;
			if ($name.length -gt 3 -and
			   !$name.contains("%"))
			{
				if (!$actions.ContainsKey($name)){
					$null = $actions.Add($name, [System.Collections.ArrayList]@());
				}

				$noApis = [regex]::replace($content, '@[^\n]*\n[^\n]*','', [System.Text.RegularExpressions.RegexOptions]::Singleline,[System.Text.RegularExpressions.RegexOptions]::IgnorePatternWhitespace)
				$matches = [regex]::matches($noApis, 'def ((?![_|on|base])\w+)\(self\)')
				foreach ($match in $matches){
					$method = $match.Groups[1].Value;
					
					if ($method -eq "unlink" -or 
						$method -eq "init" -or 
						$method -like "*button*"
						)
					{
						continue;
					}
					$null = $actions[$name].Add($match.Groups[1].Value);
				}
				if ($actions[$name].Count -eq 0){
					$actions.Remove($name);
				}		
			}					
		}
	}
$actions| ConvertTo-Json | out-File actions.json
