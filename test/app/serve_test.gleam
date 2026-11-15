import app/serve

pub fn file_for_maps_urls_into_dist_test() {
  assert serve.file_for("/") == Ok("index.html")
  assert serve.file_for("/index.html") == Ok("index.html")
  assert serve.file_for("/js/app/app.mjs?fresh=1") == Ok("js/app/app.mjs")
  assert serve.file_for("/icons/") == Ok("icons/index.html")
  assert serve.file_for("/a%20b.png") == Ok("a b.png")
}

pub fn file_for_never_leaves_dist_test() {
  assert serve.file_for("/../gleam.toml") == Error(Nil)
  assert serve.file_for("/js/%2e%2e/%2e%2e/gleam.toml") == Error(Nil)
  assert serve.file_for("/..%5C..%5Cgleam.toml") == Error(Nil)
}

pub fn content_type_test() {
  assert serve.content_type("index.html") == "text/html; charset=utf-8"
  assert serve.content_type("js/a.mjs") == "text/javascript; charset=utf-8"
  assert serve.content_type("sw.js") == "text/javascript; charset=utf-8"
  assert serve.content_type("style.css") == "text/css; charset=utf-8"
  assert serve.content_type("version.json") == "application/json"
  assert serve.content_type("manifest.webmanifest")
    == "application/manifest+json"
  assert serve.content_type("icons/icon-192.png") == "image/png"
  assert serve.content_type("LICENSE") == "application/octet-stream"
}

pub fn port_test() {
  assert serve.port([]) == Ok(8080)
  assert serve.port(["8791"]) == Ok(8791)
  assert serve.port(["0"]) == Error(Nil)
  assert serve.port(["70000"]) == Error(Nil)
  assert serve.port(["web"]) == Error(Nil)
  assert serve.port(["8791", "8792"]) == Error(Nil)
}

pub fn the_site_is_named_after_the_project_folder_test() {
  assert serve.site_name("/Users/sam/code/my-game") == "my-game"
  assert serve.site_name("C:\\src\\my-game") == "my-game"
  assert serve.site_name("/Users/sam/code/my-game/") == "my-game"
  assert serve.site_name("") == "app"
}

pub fn only_paths_under_the_site_folder_are_inside_it_test() {
  assert serve.inside_site("my-game", "my-game/index.html") == Ok("index.html")
  assert serve.inside_site("my-game", "my-game/js/app/app.mjs")
    == Ok("js/app/app.mjs")
  assert serve.inside_site("my-game", "index.html") == Error(Nil)
  assert serve.inside_site("my-game", "other/index.html") == Error(Nil)
  assert serve.inside_site("my-game", "my-game") == Error(Nil)
}
