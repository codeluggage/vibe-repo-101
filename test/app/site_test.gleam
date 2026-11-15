import app/site.{Repository}

pub fn parse_reads_both_github_forms_test() {
  let repository = Ok(Repository("owner", "repo"))
  assert site.parse("https://github.com/owner/repo.git") == repository
  assert site.parse("git@github.com:owner/repo.git") == repository
  assert site.parse("https://github.com/owner/repo") == repository
  assert site.parse("git@github.com:owner/repo\n") == repository
  assert site.parse("ssh://git@github.com/owner/repo.git") == repository
}

pub fn parse_refuses_other_addresses_test() {
  assert site.parse("") == Error(Nil)
  assert site.parse("https://gitlab.com/owner/repo.git") == Error(Nil)
  assert site.parse("https://github.com/owner") == Error(Nil)
  assert site.parse("https://github.com/owner/repo/extra") == Error(Nil)
  assert site.parse("/home/someone/repo") == Error(Nil)
}

pub fn address_is_the_pages_site_test() {
  assert site.address(Repository("owner", "repo"))
    == "https://owner.github.io/repo/"
}
