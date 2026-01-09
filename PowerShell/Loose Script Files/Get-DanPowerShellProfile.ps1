function Get-DanPowerShellProfile {
    [CmdletBinding()]
    param ()

    $Profile = @{
        Name                  = 'Dan Damit'
        Role                  = 'Deployment Engineer & Systems Architect'
        Specialization        = 'Modular Automation, Fleet Deployments, Manifest-Driven Tooling'
        PowerShellExpertise   = @(
            'Designs technician-grade scripts with manifest clarity and robust error handling',
            'Architects scalable DSCv3 pipelines with YAML parameter injection',
            'Diagnoses edge cases in installer signing, registry toggling, and bootstrapper logic',
            'Builds atomic helpers for firewall rule orchestration and config templating',
            'Empowers techs with transparent logging, modular onboarding, and disaster recovery'
        )
        Philosophy            = 'PowerShell is not just a shell—it’s a scalpel, a blueprint, and a technician’s compass.'
        SignatureFunction     = 'Invoke-DeploymentToolkit -Manifest $ManifestPath -Verbose -EmpowerTechs'
    }

    return $Profile
}

# Example usage
$DanProfile = Get-DanPowerShellProfile
$DanProfile.PowerShellExpertise | ForEach-Object { Write-Host "• $_" }