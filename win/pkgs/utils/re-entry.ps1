# ================================================================================
# Re-entry for protection.
# ================================================================================

$Env:ROASTER_REENTRY_TAG = '__roaster_reentry_tag__'

$args = $MyInvocation.UnboundArguments

if ($args.Count -lt 1 -or $args[0] -ne $Env:ROASTER_REENTRY_TAG)
{
    Write-Host "Re-entry `"$($MyInvocation.MyCommand.Path)`" with args `"$args`" for protection."
    & "${PSHOME}/powershell.exe" $MyInvocation.MyCommand.Path $Env:ROASTER_REENTRY_TAG $args
    if (-Not $?)
    {
        Write-Host "Error code returned by `"$($MyInvocation.MyCommand.Path)`"."
        exit 1
    }

    exit 0
}
