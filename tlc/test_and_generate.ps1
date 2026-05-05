# Test SGDirect specification and generate time-stamped output files
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dotFile = "state_graph_$timestamp.dot"
$edgeFile = "edge_list_$timestamp.txt"
$nodeFile = "edge_list_nodes_$timestamp.txt"

Write-Host "=== Testing SGDirect Specification ===" -ForegroundColor Green
Write-Host "Timestamp: $timestamp" -ForegroundColor Yellow
Write-Host ""

# Step 1: Run TLC to generate DOT file
Write-Host "Step 1: Running TLC to generate DOT file..." -ForegroundColor Yellow
java -jar tla2tools.jar -dump dot $dotFile SGDirect

# Step 2: Convert DOT to edge list using fast Python script
Write-Host "`nStep 2: Converting DOT to edge list..." -ForegroundColor Yellow
Write-Host "Output files:" -ForegroundColor Cyan
Write-Host "  - $dotFile" -ForegroundColor White
Write-Host "  - $edgeFile" -ForegroundColor White
Write-Host "  - $nodeFile" -ForegroundColor White
python fast_convert.py $dotFile $edgeFile

Write-Host "`n=== Done! ===" -ForegroundColor Green
