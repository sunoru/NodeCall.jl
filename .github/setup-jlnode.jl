using Pkg
Pkg.add.(["JSON", "HTTP", "Downloads"])
using JSON, HTTP, Downloads
Pkg.activate(".")
Pkg.instantiate()

using libjlnode_jll
libjlnode_jll.dev_jll()
override_folder = libjlnode_jll.artifact_dir

response = HTTP.request("GET", "https://api.github.com/repos/sunoru/jlnode/actions/artifacts")
artifacts_info = String(response.body) |> JSON.parse
artifacts_info["total_count"] == 0 && exit(0)
artifact = artifacts_info["artifacts"][1]
artifact["expired"] && exit(0)
url = artifact["archive_download_url"]
output = Downloads.download(url)
run(`7z x $output`)
rm(joinpath(override_folder, "*"), recursive=true)
mv("lib", override_folder)
