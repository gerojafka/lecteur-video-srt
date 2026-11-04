# Gestion de la bibliothèque du lecteur vidéo + sous-titres.
# Chaque vidéo est copiée avec son fichier .srt dans media-library\pieces\<id>\
# et décrite dans media-library\catalog.json, que la page lit pour afficher la liste.
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('list', 'open-library', 'add', 'add-batch', 'add-guided', 'remove-batch', 'publish', 'rebuild')]
  [string]$Action,

  [string]$Video,
  [string]$Subtitles,
  [string]$Title
)

$MaxBytes = 100MB   # GitHub refuse les fichiers de plus de 100 Mo
$repoRoot = Split-Path -Parent $PSScriptRoot
$libraryRoot = Join-Path $repoRoot 'media-library'
$piecesRoot = Join-Path $libraryRoot 'pieces'
$catalogPath = Join-Path $libraryRoot 'catalog.json'
$Ignore = [StringComparison]::OrdinalIgnoreCase

function Read-Catalog {
  if (-not (Test-Path -LiteralPath $catalogPath)) { return @() }
  $raw = [IO.File]::ReadAllText($catalogPath, [Text.Encoding]::UTF8)
  if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
  $catalog = $raw | ConvertFrom-Json
  return @($catalog.pieces | Where-Object { $_ })
}

function Read-SubtitlesText([string]$relative) {
  $path = Join-Path $libraryRoot ($relative -replace '/', '\')
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bytes = [IO.File]::ReadAllBytes($path)
  try { $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) }
  catch { $text = [Text.Encoding]::GetEncoding(1252).GetString($bytes) }
  return $text.TrimStart([char]0xFEFF)
}

# catalog.json : la liste ; catalog.js : la même liste avec le texte des .srt,
# lisible par la page même ouverte par double-clic (sans serveur).
function Save-Catalog($pieces) {
  $sorted = @($pieces | Sort-Object { $_.title })
  $utf8 = New-Object Text.UTF8Encoding $false
  $json = [ordered]@{ version = 1; pieces = $sorted } | ConvertTo-Json -Depth 6
  [IO.File]::WriteAllText($catalogPath, $json, $utf8)
  $withText = @($sorted | ForEach-Object {
      $p = [ordered]@{ id = $_.id; title = $_.title; video = $_.video }
      if ($_.subtitles) { $p.subtitles = $_.subtitles; $p.subtitlesText = Read-SubtitlesText $_.subtitles }
      [pscustomobject]$p
    })
  $js = 'window.MEDIA_LIBRARY = ' + ([ordered]@{ version = 1; pieces = $withText } | ConvertTo-Json -Depth 6 -Compress) + ';'
  [IO.File]::WriteAllText((Join-Path $libraryRoot 'catalog.js'), $js, $utf8)
}

function New-Slug([string]$value) {
  $plain = -join ($value.Normalize([Text.NormalizationForm]::FormD).ToCharArray() |
    Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
  $slug = ($plain.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($slug)) { $slug = 'video' }
  if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).Trim('-') }
  return $slug
}

function New-PieceId([string]$title, $pieces) {
  $base = New-Slug $title
  $id = $base; $n = 2
  while (@($pieces | Where-Object { $_.id -eq $id }).Count -or (Test-Path -LiteralPath (Join-Path $piecesRoot $id))) {
    $id = "$base-$n"; $n++
  }
  return $id
}

# Le .srt doit commencer par le nom de la vidéo ; les caractères en plus à la fin sont ignorés.
# Priorité : nom.fr.srt, puis nom.srt, puis un nom contenant « fr », puis le plus court.
function Find-Subtitles([string]$videoPath) {
  $folder = Split-Path -Parent $videoPath
  $stem = [IO.Path]::GetFileNameWithoutExtension($videoPath)
  $longer = @(Get-ChildItem -LiteralPath $folder -File | Where-Object {
      $_.Extension -in '.mp4', '.m4v', '.mov', '.webm' -and $_.BaseName.Length -gt $stem.Length -and $_.BaseName.StartsWith($stem, $Ignore)
    } | ForEach-Object { $_.BaseName })
  $candidates = @(Get-ChildItem -LiteralPath $folder -File | Where-Object {
      $name = $_.BaseName
      $_.Extension -in '.srt', '.vtt' -and $name.StartsWith($stem, $Ignore) -and
      -not @($longer | Where-Object { $name.StartsWith($_, $Ignore) }).Count
    })
  if (-not $candidates.Count) { return $null }
  $best = $candidates | Sort-Object @{ Expression = {
      $extra = $_.BaseName.Substring($stem.Length).ToLowerInvariant()
      if ($extra -match '^[ ._-]*fr$') { 0 }
      elseif ($extra -eq '') { 1 }
      elseif ($extra -match '(^|[^a-z])fr([^a-z]|$)') { 2 }
      else { 3 }
    } }, @{ Expression = { $_.BaseName.Length } } | Select-Object -First 1
  return $best.FullName
}

function Test-Size([string]$path) {
  $size = (Get-Item -LiteralPath $path).Length
  if ($size -gt $MaxBytes) {
    Write-Warning ("{0} fait {1:N0} Mo : GitHub refuse les fichiers de plus de 100 Mo." -f (Split-Path -Leaf $path), ($size / 1MB))
    return $false
  }
  return $true
}

function Add-Piece([string]$videoPath, [string]$subsPath, [string]$displayTitle, [ref]$piecesRef) {
  if (-not (Test-Size $videoPath)) { return $false }
  if (-not $displayTitle) { $displayTitle = [IO.Path]::GetFileNameWithoutExtension($videoPath) }
  $id = New-PieceId $displayTitle $piecesRef.Value
  $folder = Join-Path $piecesRoot $id
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  try {
    $videoName = Split-Path -Leaf $videoPath
    Copy-Item -LiteralPath $videoPath -Destination (Join-Path $folder $videoName) -Force
    $piece = [ordered]@{ id = $id; title = $displayTitle; video = "pieces/$id/$videoName" }
    if ($subsPath) {
      $subsName = Split-Path -Leaf $subsPath
      Copy-Item -LiteralPath $subsPath -Destination (Join-Path $folder $subsName) -Force
      $piece.subtitles = "pieces/$id/$subsName"
    }
    $piecesRef.Value = @($piecesRef.Value) + [pscustomobject]$piece
    Write-Host ("Ajouté : {0}{1}" -f $displayTitle, $(if ($subsPath) { "  +  $(Split-Path -Leaf $subsPath)" } else { '  (sans sous-titres)' }))
    return $true
  } catch {
    if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
    Write-Warning "Impossible d'ajouter $videoPath : $($_.Exception.Message)"
    return $false
  }
}

function Select-Files([string]$title, [string]$filter, [bool]$multi) {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = $title
  $dialog.Filter = "$filter|Tous les fichiers (*.*)|*.*"
  $dialog.Multiselect = $multi
  $dialog.CheckFileExists = $true
  $dialog.RestoreDirectory = $true
  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return @() }
  return @($dialog.FileNames)
}

function Select-PieceFolders($pieces) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $folders = @(Get-ChildItem -LiteralPath $piecesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
  if (-not $folders.Count) { return @() }
  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'Choisir les vidéos à enlever'
  $form.StartPosition = 'CenterScreen'
  $form.Size = New-Object System.Drawing.Size(720, 560)
  $label = New-Object System.Windows.Forms.Label
  $label.Text = "Cochez les vidéos à enlever de la bibliothèque :`r`n$piecesRoot"
  $label.Dock = 'Top'; $label.Height = 48
  $label.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 4)
  $list = New-Object System.Windows.Forms.CheckedListBox
  $list.Dock = 'Fill'; $list.CheckOnClick = $true; $list.IntegralHeight = $false
  $list.Font = New-Object System.Drawing.Font('Segoe UI', 10)
  foreach ($folder in $folders) {
    $piece = @($pieces | Where-Object { $_.id -eq $folder.Name }) | Select-Object -First 1
    $t = if ($piece) { $piece.title } else { '(absent de catalog.json)' }
    [void]$list.Items.Add("$t  [$($folder.Name)]")
  }
  $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
  $buttons.Dock = 'Bottom'; $buttons.Height = 52; $buttons.FlowDirection = 'RightToLeft'
  $buttons.Padding = New-Object System.Windows.Forms.Padding(8)
  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = 'Enlever les vidéos cochées'; $ok.Width = 190
  $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = 'Annuler'; $cancel.Width = 90
  $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $buttons.Controls.Add($ok); $buttons.Controls.Add($cancel)
  $form.Controls.Add($list); $form.Controls.Add($label); $form.Controls.Add($buttons)
  $form.AcceptButton = $ok; $form.CancelButton = $cancel
  if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return @() }
  return @($list.CheckedIndices | ForEach-Object { $folders[$_].Name })
}

New-Item -ItemType Directory -Force -Path $piecesRoot | Out-Null
$pieces = @(Read-Catalog)
if (-not (Test-Path -LiteralPath $catalogPath)) { Save-Catalog @() }

switch ($Action) {
  'list' {
    if (-not $pieces.Count) { Write-Output 'La bibliothèque est vide.'; break }
    $pieces | ForEach-Object { Write-Output ("{0}  |  {1}" -f $_.title, $(if ($_.subtitles) { 'vidéo + sous-titres' } else { 'vidéo seule' })) }
  }
  'rebuild' {
    Save-Catalog $pieces
    Write-Output ("Catalogue régénéré : {0} vidéo(s)." -f $pieces.Count)
  }
  'open-library' {
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $libraryRoot)
    Write-Output "Bibliothèque ouverte : $libraryRoot"
  }
  'add' {
    if (-not $Video -or -not (Test-Path -LiteralPath $Video)) { throw "Vidéo introuvable : $Video" }
    if ($Subtitles -and -not (Test-Path -LiteralPath $Subtitles)) { throw "Sous-titres introuvables : $Subtitles" }
    $videoPath = (Resolve-Path -LiteralPath $Video).Path
    $subsPath = if ($Subtitles) { (Resolve-Path -LiteralPath $Subtitles).Path } else { Find-Subtitles $videoPath }
    if (Add-Piece $videoPath $subsPath $Title ([ref]$pieces)) { Save-Catalog $pieces }
  }
  'add-batch' {
    $videos = Select-Files 'Choisir une ou plusieurs vidéos (Ctrl ou Maj pour en prendre plusieurs)' 'Vidéos (*.mp4;*.m4v;*.mov;*.webm)|*.mp4;*.m4v;*.mov;*.webm' $true
    if (-not $videos.Count) { Write-Output 'Aucun fichier sélectionné.'; break }
    $added = 0; $skipped = 0
    foreach ($videoPath in $videos) {
      $subsPath = Find-Subtitles $videoPath
      if (-not $subsPath) {
        Write-Warning ("Pas de .srt commençant par « {0} » dans le même dossier : vidéo ignorée." -f [IO.Path]::GetFileNameWithoutExtension($videoPath))
        $skipped++; continue
      }
      if (Add-Piece $videoPath $subsPath $null ([ref]$pieces)) { $added++ } else { $skipped++ }
    }
    if ($added) { Save-Catalog $pieces }
    Write-Output ''
    Write-Output "$added vidéo(s) + sous-titres ajoutée(s)."
    if ($skipped) { Write-Output "$skipped vidéo(s) ignorée(s)." }
  }
  'add-guided' {
    $videoPath = @(Select-Files 'Choisir la vidéo' 'Vidéos (*.mp4;*.m4v;*.mov;*.webm)|*.mp4;*.m4v;*.mov;*.webm' $false) | Select-Object -First 1
    if (-not $videoPath) { Write-Output 'Aucun fichier sélectionné.'; break }
    $subsPath = @(Select-Files 'Choisir le fichier de sous-titres (Annuler pour ignorer)' 'Sous-titres (*.srt;*.vtt)|*.srt;*.vtt' $false) | Select-Object -First 1
    if (Add-Piece $videoPath $subsPath $null ([ref]$pieces)) { Save-Catalog $pieces }
  }
  'remove-batch' {
    $ids = @(Select-PieceFolders $pieces)
    if (-not $ids.Count) { Write-Output 'Aucune vidéo sélectionnée.'; break }
    foreach ($id in $ids) {
      $folder = Join-Path $piecesRoot $id
      if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
    }
    $removed = @($pieces | Where-Object { $_.id -in $ids } | ForEach-Object { $_.title })
    $pieces = @($pieces | Where-Object { $_.id -notin $ids })
    Save-Catalog $pieces
    Write-Output ("Enlevé(s) : " + ($removed -join ', '))
  }
  'publish' {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git est introuvable sur cet ordinateur.' }
    Push-Location $repoRoot
    try {
      git add -A -- media-library
      $changes = git status --porcelain -- media-library
      if (-not $changes) {
        Write-Output 'Rien de nouveau à publier.'
      } else {
        git commit -q -m 'Bibliothèque : mise à jour des vidéos' -- media-library
        if (-not (git remote)) {
          Write-Output "Enregistré dans le dépôt local. Aucun dépôt GitHub n'est encore relié : la publication se fera une fois le dépôt créé."
        } else {
          git push
          if ($LASTEXITCODE -ne 0) { throw "L'envoi vers GitHub a échoué." }
          Write-Output "Publié. La liste sera à jour sur l'iPad / l'iPhone d'ici une à deux minutes."
        }
      }
    } finally { Pop-Location }
  }
}
