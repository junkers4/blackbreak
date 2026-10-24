# A window on the normal desktop that records what reaches it: "text|clicks|textX|textY|buttonX|buttonY".
param([Parameter(Mandatory)][string]$Log)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$f = New-Object Windows.Forms.Form
$f.Text = 'BlackBreak test target'
$f.TopMost = $true
$f.StartPosition = 'CenterScreen'
$f.Size = New-Object Drawing.Size 420, 320
$tb = New-Object Windows.Forms.TextBox
$tb.SetBounds(20, 20, 360, 30)
$b = New-Object Windows.Forms.Button
$b.Text = 'Click me'
$b.SetBounds(20, 80, 360, 160)
$f.Controls.AddRange(@($tb, $b))
$script:clicks = 0
$b.Add_Click({ $script:clicks++ })
$t = New-Object Windows.Forms.Timer
$t.Interval = 150
$t.Add_Tick({
    $tp = $tb.PointToScreen((New-Object Drawing.Point 30, 12))
    $bp = $b.PointToScreen((New-Object Drawing.Point 180, 80))
    "$($tb.Text)|$($script:clicks)|$($tp.X)|$($tp.Y)|$($bp.X)|$($bp.Y)" | Set-Content -NoNewline $Log
})
$t.Start()
$f.Add_Shown({ $f.Activate(); $tb.Focus() })
[Windows.Forms.Application]::Run($f)
