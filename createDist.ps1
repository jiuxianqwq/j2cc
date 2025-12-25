if (Test-Path "dist_package") { Remove-Item -Recurse -Force "dist_package" }
if (Test-Path "dist.tar.gz") { Remove-Item -Force "dist.tar.gz" }

New-Item -ItemType Directory -Force -Path "dist_package" | Out-Null

Copy-Item -Recurse -Force "core/target/dist-core/*" "dist_package/"

Copy-Item -Recurse -Force "util" "dist_package/util"

if (Test-Path "natives") { Copy-Item -Recurse -Force "natives" "dist_package/natives" }

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "dist_package/util/.idea"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "dist_package/util/cmake-build-*"
Remove-Item -Force -ErrorAction SilentlyContinue "dist_package/util/CMakeLists.txt"

Write-Host "构建完成！分发包已生成在 dist_package 文件夹中。" -ForegroundColor Green