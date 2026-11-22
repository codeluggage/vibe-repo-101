//// `gleam run -m app/publish` takes the work saved on `main` to the live
//// site and says in its last line which version is live. Its reader is a
//// small language model that repeats that line to a person who is not a
//// developer, so every message is one or two plain sentences.
////
//// In order: on main with nothing unsaved; take in the changes on GitHub,
//// when GitHub has a main yet; the checks and the build; the storage schema
//// number against the live site; turn the website on when it is off; send
//// the change to GitHub; wait for GitHub to publish it; wait for the live
//// site to show it; look for its version tag. Each failure stops there,
//// changes nothing further and says so. With nothing to send it only waits,
//// so a publish that was cut off picks up its wait when it runs again, and it
//// also answers which version is live. A run that failed on GitHub outside
//// the checks is sent once more.

import app/live_check.{
  type Verdict, CannotTell, MayGoLive, NotLater, OlderLayout,
}
import app/site.{type Repository}
import app/version
import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Check {
  Format
  Types
  Tests
  Build
}

/// How a publish ended.
pub type Outcome {
  NotOnMain(branch: String)
  Unsaved
  NoAddress
  CouldNotRun(program: String)
  Unreachable
  SameLines
  NotCombined
  CheckFailed(Check)
  /// The new build keeps saved data at a lower storage schema number than
  /// the live site.
  StepRemoved
  /// GitHub did not turn the website on, because the project is private.
  /// The work was still sent, so GitHub keeps a copy of it.
  PrivateProject
  /// GitHub did not turn the website on for another reason, which it gave.
  WebsiteNotOn
  /// The person may not change the project on GitHub: it is someone else's.
  NoPermission
  NotSent
  /// A check failed on GitHub and passed on this computer.
  FailedOnlyOnGitHub(Check)
  /// The run failed again after publish sent the work once more.
  FailedAgain(step: Option(String))
  RunNotStarted
  RunTooSlow
  StatusUnreadable
  NotShownYet
  /// `tagged` is False when GitHub did not tag the commit with the version.
  Live(release: String, tagged: Bool)
}

/// An outcome that stops the publish, and what the failing program printed,
/// shown above the sentence.
type Stop =
  #(Outcome, String)

const checks = [
  #(Format, ["format", "--check", "src", "test", "dev"]),
  #(Types, ["check"]),
  #(Tests, ["test"]),
  #(Build, ["run", "-m", "app/build"]),
]

/// The message of the empty commit that sends the same work once more.
pub const again = "publish again"

/// The steps of `deploy.yml` that run a check publish can run here, by the
/// name GitHub gives them. A test reads `deploy.yml` for each name.
pub const check_steps = [
  #("Check the types", Types),
  #("Run the tests", Tests),
  #("Build the site", Build),
]

/// The job of `deploy.yml` that puts the site live.
pub const deploy_job = "deploy"

/// The wait between two questions about the run. Without gh, GitHub answers
/// 60 questions an hour, and one publish asks at most 34.
const run_poll_ms = 20_000

/// Three minutes for the run to appear, ten for it to finish.
const start_polls = 9

const run_polls = 30

/// Five minutes for the live site to show the change.
const live_poll_ms = 10_000

const live_polls = 30

pub fn main() -> Nil {
  let _ = {
    use published <- promise.map(publish())
    case published {
      Ok(live) -> io.println(say(live))
      Error(#(outcome, detail)) -> {
        case string.trim(detail) {
          "" -> Nil
          detail -> io.println(detail)
        }
        io.println(say(outcome))
        // A private project's work is saved, so that is no failure.
        case outcome {
          PrivateProject -> Nil
          _ -> set_exit_code(1)
        }
      }
    }
  }
  Nil
}

/// The last words of a publish.
pub fn say(outcome: Outcome) -> String {
  let unpublished = ", so nothing was published."
  let unchanged = ", so the live site is unchanged."
  let ask = " Ask the person who helps with the project."
  let later = " Run this command again later to see which version is live."
  case outcome {
    NotOnMain("") ->
      "Publishing works only from main, and this copy is not on main"
      <> unpublished
    NotOnMain(branch) ->
      "Publishing works only from main, and this copy is on \""
      <> branch
      <> "\""
      <> unpublished
    Unsaved ->
      "Some changes are not saved to the project history yet" <> unpublished
    NoAddress ->
      "This copy of the project has no address on GitHub" <> unpublished <> ask
    CouldNotRun(program) ->
      "The program " <> program <> " did not work" <> unpublished <> ask
    Unreachable ->
      "GitHub could not be reached"
      <> unpublished
      <> " Check the internet connection and try again."
    SameLines ->
      "This change and a change from another person touch the same lines"
      <> unpublished
      <> ask
    NotCombined ->
      "The changes on GitHub could not be combined with this one"
      <> unpublished
      <> ask
    CheckFailed(Format) ->
      "The code is not formatted"
      <> unpublished
      <> " Run gleam format src test dev and publish again."
    CheckFailed(Types) ->
      "The code has errors"
      <> unpublished
      <> " Fix what gleam check says above and publish again."
    CheckFailed(Tests) ->
      "A test failed"
      <> unpublished
      <> " Fix what gleam test says above and publish again."
    CheckFailed(Build) ->
      "The site could not be built"
      <> unpublished
      <> " Fix what the build says above and publish again."
    StepRemoved ->
      "This change removes a storage step that phones already have"
      <> unpublished
      <> " Put the step back in upgrades in src/app/storage.gleam."
    PrivateProject ->
      "Your work is saved on GitHub, but this project is private, and GitHub puts a private project online only on a paid GitHub plan."
      <> " Use the copy on this computer with gleam run -m app/serve, or make the project public on GitHub."
    WebsiteNotOn ->
      "GitHub did not turn on the website for this project"
      <> unpublished
      <> " GitHub's own words are in the lines above."
    NoPermission ->
      "This folder is a copy of a project you cannot change online"
      <> unpublished
      <> " The app still runs on this computer with gleam run -m app/build then gleam run -m app/serve, and START-HERE.md says how to make your own project from it."
    NotSent -> "GitHub did not take the change" <> unpublished <> ask
    FailedOnlyOnGitHub(check) ->
      "The "
      <> check_name(check)
      <> " failed on GitHub, but the same checks passed on this computer"
      <> unchanged
      <> ask
    FailedAgain(Some(step)) ->
      "The step \"" <> step <> "\" failed on GitHub again" <> unchanged <> ask
    FailedAgain(None) -> "Publishing failed on GitHub again" <> unchanged <> ask
    RunNotStarted ->
      "GitHub has not started publishing after three minutes." <> later
    RunTooSlow -> "GitHub is still publishing after ten minutes." <> later
    StatusUnreadable -> "GitHub did not say how publishing went." <> later
    NotShownYet ->
      "GitHub has published, but the live site does not show it after five minutes."
      <> later
    Live(release, tagged) -> {
      let untagged = case tagged {
        True -> ""
        False ->
          "Version "
          <> release
          <> " is live, but the list of versions will not show it. Tell the person who helps with the project.\n"
      }
      untagged
      <> "Version "
      <> release
      <> " is live.\nOpen the app. If a bar says \"New version\", tap Reload."
    }
  }
}

fn check_name(check: Check) -> String {
  case check {
    Format -> "format check"
    Types -> "type check"
    Tests -> "tests"
    Build -> "build"
  }
}

/// Whether a build may be sent, from the live check's verdict on it. Only a
/// lower storage schema number stops it here. GitHub's own build stamped the
/// live version, so this computer's clock says nothing true about whether
/// the new one is later: the same check on GitHub decides, and a run that
/// fails there is sent once more.
pub fn may_send(verdict: Verdict) -> Result(Nil, Outcome) {
  case verdict {
    OlderLayout(_) -> Error(StepRemoved)
    NotLater(_) | MayGoLive(_) | CannotTell(_) -> Ok(Nil)
  }
}

/// What publish does after the run it waited for failed.
pub type Retry {
  /// A check failed on GitHub: run the checks here, then ask for help.
  CheckHere(Check)
  /// Send the same work once more, as an empty commit with the message
  /// `again`.
  SendAgain
  /// It was sent once more and failed again.
  GiveUp
}

/// What to do about a failed run, from the name of the step that failed,
/// when GitHub said it, and the first line of the message of the commit the
/// run was for.
pub fn retry(step: Option(String), subject: String) -> Retry {
  let check =
    option.to_result(step, Nil) |> result.try(list.key_find(check_steps, _))
  case check {
    Ok(check) -> CheckHere(check)
    Error(Nil) if subject == again -> GiveUp
    Error(Nil) -> SendAgain
  }
}

pub type Push {
  Sent
  /// GitHub has changes this copy has not taken in yet.
  Behind
  /// The person may not write to the project on GitHub.
  Denied
  Refused
}

/// What `git push --porcelain` did, from its exit status, its standard
/// output, where a refused ref is a line that starts with `!`, and its error
/// output, where GitHub says when the person may not write.
pub fn read_push(status: Int, porcelain: String, error: String) -> Push {
  let refused =
    string.split(porcelain, "\n")
    |> list.filter(string.starts_with(_, "!"))
  let behind =
    list.any(refused, fn(line) {
      string.contains(line, "fetch first")
      || string.contains(line, "non-fast-forward")
    })
  // GitHub's own words over HTTPS and SSH, and git's for an HTTP 403.
  let denied =
    {
      string.contains(error, "Permission to")
      && string.contains(error, "denied")
    }
    || string.contains(error, "Write access to repository not granted")
    || string.contains(error, "The requested URL returned error: 403")
  case denied, refused, behind, status {
    True, _, _, _ -> Denied
    _, _, True, _ -> Behind
    _, [], _, 0 -> Sent
    _, _, _, _ -> Refused
  }
}

/// Whether `git ls-remote --exit-code --heads origin main` says that GitHub
/// has no main yet, as for the first publish to a new project: it exits 2
/// when no branch matches.
pub fn missing_main(ls_remote: Result(#(Int, String, String), String)) -> Bool {
  case ls_remote {
    Ok(#(2, _, _)) -> True
    Ok(_) | Error(_) -> False
  }
}

/// Whether GitHub serves the project's website.
pub type Website {
  WebsiteOn
  WebsiteOff
  /// GitHub gave no answer this reads, such as with no internet.
  WebsiteUnknown
}

/// The website from GitHub's answer to `repos/<owner>/<repo>/pages`, which is
/// 404 when it is off.
pub fn read_website(answer: Result(#(Int, String), String)) -> Website {
  case answer {
    Ok(#(200, _)) -> WebsiteOn
    Ok(#(404, _)) -> WebsiteOff
    Ok(_) | Error(_) -> WebsiteUnknown
  }
}

/// Why GitHub did not turn the website on, from its answer about the
/// repository: the person may not change it, it is private, or neither, and
/// then `words`, what GitHub said when it did not turn the website on, go
/// above the sentence.
pub fn website_refused(
  repository: Result(#(Int, String), String),
  words: String,
) -> #(Outcome, String) {
  // `permissions` is there only when the question was asked signed in.
  let decoder = {
    use private <- decode.field("private", decode.bool)
    use may_push <- decode.optional_field(
      "permissions",
      True,
      decode.at(["push"], decode.bool),
    )
    decode.success(#(private, may_push))
  }
  let read = case repository {
    Ok(#(200, body)) -> json.parse(body, decoder) |> result.replace_error(Nil)
    Ok(_) | Error(_) -> Error(Nil)
  }
  case read {
    Ok(#(_, False)) -> #(NoPermission, "")
    Ok(#(True, True)) -> #(PrivateProject, "")
    Ok(#(False, True)) | Error(Nil) -> #(WebsiteNotOn, words)
  }
}

pub type Run {
  NoRun
  Running
  Passed
  Cancelled
  Failed(id: Int)
}

/// The newest run in a list of workflow runs as the GitHub API sends it,
/// newest first.
pub fn read_runs(text: String) -> Result(Run, Nil) {
  let run = {
    use id <- decode.field("id", decode.int)
    use status <- decode.field("status", decode.string)
    use conclusion <- decode.field("conclusion", decode.optional(decode.string))
    decode.success(#(id, status, conclusion))
  }
  let decoder = decode.at(["workflow_runs"], decode.list(run))
  use runs <- result.map(json.parse(text, decoder) |> result.replace_error(Nil))
  case runs {
    [] -> NoRun
    [#(_, "completed", Some("success")), ..] -> Passed
    [#(_, "completed", Some("cancelled")), ..] -> Cancelled
    [#(id, "completed", _), ..] -> Failed(id)
    [_, ..] -> Running
  }
}

pub type Failure {
  /// The site went live and only a later job failed.
  WentLive
  FailedAt(step: String)
  FailedSomewhere
}

/// Why a run failed, from its jobs as the GitHub API sends them.
pub fn read_jobs(text: String) -> Result(Failure, Nil) {
  let step = {
    use name <- decode.field("name", decode.string)
    use conclusion <- decode.field("conclusion", decode.optional(decode.string))
    decode.success(#(name, conclusion))
  }
  let job = {
    use name <- decode.field("name", decode.string)
    use conclusion <- decode.field("conclusion", decode.optional(decode.string))
    use steps <- decode.optional_field("steps", [], decode.list(step))
    decode.success(#(name, conclusion, steps))
  }
  let decoder = decode.at(["jobs"], decode.list(job))
  use jobs <- result.map(json.parse(text, decoder) |> result.replace_error(Nil))
  let deployed =
    list.any(jobs, fn(job) { job.0 == deploy_job && job.1 == Some("success") })
  let failed_step =
    list.find_map(jobs, fn(job) {
      list.find_map(job.2, fn(step) {
        case step {
          #(name, Some("failure")) -> Ok(name)
          _ -> Error(Nil)
        }
      })
    })
  case deployed, failed_step {
    True, _ -> WentLive
    False, Ok(step) -> FailedAt(step)
    False, Error(Nil) -> FailedSomewhere
  }
}

/// The body gh printed when `gh api` ran and succeeded. Any other result, gh
/// missing, not signed in or failing for a reason of its own, is
/// `Error(Nil)`, and publish asks GitHub directly instead.
pub fn read_gh(
  ran: Result(#(Int, String, String), String),
) -> Result(String, Nil) {
  case ran {
    Ok(#(0, body, _)) -> Ok(body)
    Ok(_) | Error(_) -> Error(Nil)
  }
}

// --- The thin layer: processes and requests ---------------------------------

fn publish() -> Promise(Result(Outcome, Stop)) {
  case prepare() {
    Error(stop) -> promise.resolve(Error(stop))
    Ok(repository) -> {
      use commit <- promise.try_await(send(repository, tries: 2))
      deploy(repository, commit)
    }
  }
}

/// Steps 1 and 2: on main with nothing unsaved, and the project on GitHub.
fn prepare() -> Result(Repository, Stop) {
  use branch <- result.try(git(["branch", "--show-current"]))
  let branch = string.trim(branch)
  use <- bool.guard(branch != "main", Error(#(NotOnMain(branch), "")))
  use status <- result.try(git(["status", "--porcelain"]))
  use <- bool.guard(string.trim(status) != "", Error(#(Unsaved, status)))
  site.origin() |> result.map_error(fn(reason) { #(NoAddress, reason) })
}

/// What `turn_website_on` answers for a private project on a free plan.
const private: Result(Nil, Stop) = Error(#(PrivateProject, ""))

/// Steps 3 to 5: the commit that GitHub has, sent now or before.
fn send(
  repository: Repository,
  tries tries: Int,
) -> Promise(Result(String, Stop)) {
  let ready = {
    use on_github <- result.try(take_in())
    use commit <- result.try(git(["rev-parse", "HEAD"]))
    let commit = string.trim(commit)
    use <- bool.guard(on_github == Some(commit), Ok(#(commit, False)))
    use _ <- result.map(run_checks())
    #(commit, True)
  }
  case ready {
    Error(stop) -> promise.resolve(Error(stop))
    Ok(#(commit, False)) -> {
      use website <- promise.map(turn_website_on(repository))
      case website == private {
        True -> Error(#(PrivateProject, ""))
        False -> Ok(commit)
      }
    }
    Ok(#(commit, True)) -> {
      use _ <- promise.try_await(check_live(repository))
      use website <- promise.await(turn_website_on(repository))
      // A private project on a free plan has no website. Its work is still
      // sent, so GitHub keeps a copy of it.
      let saved_only = website == private
      use _ <- promise.try_await(
        promise.resolve(case saved_only {
          True -> Ok(Nil)
          False -> website
        }),
      )
      io.println("Sending the change to GitHub.")
      // Never forced: a plain push of main, which GitHub refuses when it has
      // changes this copy has not taken in.
      case run("git", ["push", "--porcelain", "origin", "main"]) {
        Error(reason) -> promise.resolve(Error(#(CouldNotRun("git"), reason)))
        Ok(#(status, out, error)) ->
          case read_push(status, out, error), tries {
            Sent, _ if saved_only ->
              promise.resolve(Error(#(PrivateProject, "")))
            Sent, _ -> promise.resolve(Ok(commit))
            Behind, 2 -> send(repository, tries: 1)
            Denied, _ -> promise.resolve(Error(#(NoPermission, out <> error)))
            _, _ -> promise.resolve(Error(#(NotSent, out <> error)))
          }
      }
    }
  }
}

/// Fetch and merge GitHub's main, never a rebase. A conflict is undone. The
/// commit GitHub's main is at, or `None` when GitHub has no main yet, as for
/// the first publish to a new project: then there is nothing to merge.
fn take_in() -> Result(Option(String), Stop) {
  io.println("Taking in the changes on GitHub.")
  use fetched <- result.try(
    run("git", ["fetch", "origin", "main"])
    |> result.map_error(fn(reason) { #(CouldNotRun("git"), reason) }),
  )
  case fetched {
    #(0, _, _) -> merge()
    #(_, out, error) -> {
      let ls_remote =
        run("git", ["ls-remote", "--exit-code", "--heads", "origin", "main"])
      case missing_main(ls_remote) {
        True -> Ok(None)
        False -> Error(#(Unreachable, out <> error))
      }
    }
  }
}

fn merge() -> Result(Option(String), Stop) {
  case run("git", ["merge", "--no-edit", "origin/main"]) {
    Ok(#(0, _, _)) ->
      git(["rev-parse", "origin/main"])
      |> result.map(fn(out) { Some(string.trim(out)) })
    Ok(#(_, out, error)) ->
      // Only a merge left half done can be aborted, and that is a conflict.
      case run("git", ["merge", "--abort"]) {
        Ok(#(0, _, _)) -> Error(#(SameLines, out <> error))
        _ -> Error(#(NotCombined, out <> error))
      }
    Error(reason) -> Error(#(CouldNotRun("git"), reason))
  }
}

/// GitHub serves the website only once it is turned on, so before the push,
/// turn it on when it is off. When GitHub cannot say, the push goes ahead and
/// the run on GitHub tells.
fn turn_website_on(repository: Repository) -> Promise(Result(Nil, Stop)) {
  use answer <- promise.await(ask_github(api(repository, "/pages")))
  case read_website(answer) {
    WebsiteOn | WebsiteUnknown -> promise.resolve(Ok(Nil))
    WebsiteOff -> {
      let args = [
        "api",
        "-X",
        "POST",
        api(repository, "/pages"),
        "-f",
        "build_type=workflow",
      ]
      case run("gh", args) {
        Ok(#(0, _, _)) -> {
          io.println("The website was off on GitHub, so publish turned it on.")
          promise.resolve(Ok(Nil))
        }
        failed -> {
          let words = case failed {
            Ok(#(_, out, error)) -> out <> "\n" <> error
            Error(reason) -> reason
          }
          use about <- promise.map(ask_github(api(repository, "")))
          Error(website_refused(about, words))
        }
      }
    }
  }
}

fn run_checks() -> Result(Nil, Stop) {
  io.println("Checking the code and building the site.")
  list.try_each(checks, fn(check) {
    case run("gleam", check.1) {
      Ok(#(0, _, _)) -> Ok(Nil)
      Ok(#(_, out, error)) -> Error(#(CheckFailed(check.0), out <> error))
      Error(reason) -> Error(#(CouldNotRun("gleam"), reason))
    }
  })
}

/// The live check GitHub runs before it publishes, on the build in `dist/`,
/// so a lower storage schema number is known before anything is sent.
fn check_live(repository: Repository) -> Promise(Result(Nil, Stop)) {
  case live_check.read_built() {
    Error(reason) -> promise.resolve(Error(#(CheckFailed(Build), reason)))
    Ok(built) -> {
      use live <- promise.map(site.live_version(repository))
      live_check.decide(built, live)
      |> may_send
      |> result.map_error(fn(outcome) { #(outcome, "") })
    }
  }
}

/// Steps 6 to 8 for `commit`, which GitHub has.
fn deploy(
  repository: Repository,
  commit: String,
) -> Promise(Result(Outcome, Stop)) {
  io.println("Waiting for GitHub to publish. This takes a few minutes.")
  use failed <- promise.try_await(wait_for_run(
    repository,
    "head_sha=" <> commit,
    0,
  ))
  case failed {
    None -> go_live(repository, commit)
    Some(id) -> {
      use answer <- promise.await(
        ask_github(api(
          repository,
          "/actions/runs/" <> int.to_string(id) <> "/jobs",
        )),
      )
      case read_answer(answer, read_jobs) {
        Ok(WentLive) -> go_live(repository, commit)
        Ok(FailedAt(step)) -> try_again(repository, Some(step))
        Ok(FailedSomewhere) | Error(_) -> try_again(repository, None)
      }
    }
  }
}

/// Step 6: the deploy run of `query`, or the newest on main once a newer push
/// has taken over. The id of the run when it failed.
fn wait_for_run(
  repository: Repository,
  query: String,
  polls: Int,
) -> Promise(Result(Option(Int), Stop)) {
  use answer <- promise.await(
    ask_github(api(
      repository,
      "/actions/workflows/deploy.yml/runs?event=push&per_page=1&" <> query,
    )),
  )
  let poll_again = fn(query) {
    use _ <- promise.await(promise.wait(run_poll_ms))
    wait_for_run(repository, query, polls + 1)
  }
  case read_answer(answer, read_runs) {
    Error(detail) -> promise.resolve(Error(#(StatusUnreadable, detail)))
    Ok(Passed) -> promise.resolve(Ok(None))
    Ok(Failed(id)) -> promise.resolve(Ok(Some(id)))
    Ok(NoRun) if polls >= start_polls ->
      promise.resolve(Error(#(RunNotStarted, "")))
    Ok(_) if polls >= run_polls -> promise.resolve(Error(#(RunTooSlow, "")))
    Ok(Cancelled) -> poll_again("branch=main")
    Ok(NoRun) | Ok(Running) -> poll_again(query)
  }
}

/// After a failed run: check here and ask for help, send the same work once
/// more, or give up.
fn try_again(
  repository: Repository,
  step: Option(String),
) -> Promise(Result(Outcome, Stop)) {
  let subject = git(["log", "-1", "--format=%s"]) |> result.map(string.trim)
  case result.map(subject, retry(step, _)) {
    Error(stop) -> promise.resolve(Error(stop))
    Ok(CheckHere(check)) ->
      promise.resolve({
        use _ <- result.try(run_checks())
        Error(#(FailedOnlyOnGitHub(check), ""))
      })
    Ok(GiveUp) -> promise.resolve(Error(#(FailedAgain(step), "")))
    Ok(SendAgain) -> {
      io.println("Publishing failed on GitHub, so it is sent once more.")
      case git(["commit", "--allow-empty", "--message", again]) {
        Error(stop) -> promise.resolve(Error(stop))
        Ok(_) -> {
          use commit <- promise.try_await(send(repository, tries: 2))
          deploy(repository, commit)
        }
      }
    }
  }
}

/// Steps 7 and 8: the live version, and whether GitHub tagged it, which it
/// does once the site is live.
fn go_live(
  repository: Repository,
  commit: String,
) -> Promise(Result(Outcome, Stop)) {
  io.println("Waiting for the live site to show it.")
  use release <- promise.try_await(wait_for_live(repository, commit, 0))
  let tagged = case run("git", ["ls-remote", "--tags", "origin", release]) {
    Ok(#(0, out, _)) -> string.trim(out) != ""
    // Not known, so nothing is said about it.
    _ -> True
  }
  promise.resolve(Ok(Live(release:, tagged:)))
}

/// Step 7: the live release once the live site runs `commit` or a later
/// commit that contains it.
fn wait_for_live(
  repository: Repository,
  commit: String,
  polls: Int,
) -> Promise(Result(String, Stop)) {
  use answer <- promise.await(site.live_version(repository))
  let live = case answer {
    Ok(#(200, body)) ->
      case version.stamp_from_json(body) {
        Ok(live) ->
          case contains(live.commit, commit) {
            True -> Some(version.to_string(live.release))
            False -> None
          }
        _ -> None
      }
    _ -> None
  }
  case live {
    Some(release) -> promise.resolve(Ok(release))
    None if polls >= live_polls -> promise.resolve(Error(#(NotShownYet, "")))
    None -> {
      use _ <- promise.await(promise.wait(live_poll_ms))
      wait_for_live(repository, commit, polls + 1)
    }
  }
}

/// Whether the short commit `live` is `commit` or a later one that holds it.
/// A commit this copy has not seen yet is fetched first.
fn contains(live: String, commit: String) -> Bool {
  let is_ancestor = fn() {
    run("git", ["merge-base", "--is-ancestor", commit, live])
  }
  use <- bool.guard(live == "", False)
  use <- bool.guard(string.starts_with(commit, live), True)
  case is_ancestor() {
    Ok(#(0, _, _)) -> True
    Ok(#(1, _, _)) -> False
    _ -> {
      let _ = run("git", ["fetch", "--quiet", "origin", "main"])
      is_ancestor()
      |> result.map(fn(out) { out.0 == 0 })
      |> result.unwrap(False)
    }
  }
}

/// The API path of this project's repository, then `path`, such as `/pages`.
fn api(repository: Repository, path: String) -> String {
  "repos/" <> repository.owner <> "/" <> repository.name <> path
}

/// A GitHub API answer as #(HTTP status, body). It asks through `gh api`,
/// signed in on this computer, and asks GitHub directly, without a sign-in,
/// when gh fails for any reason. Only an answer that fails then too says that
/// GitHub did not answer.
fn ask_github(path: String) -> Promise(Result(#(Int, String), String)) {
  case read_gh(run("gh", ["api", path])) {
    Ok(body) -> promise.resolve(Ok(#(200, body)))
    Error(Nil) -> fetch_text("https://api.github.com/" <> path)
  }
}

fn read_answer(
  answer: Result(#(Int, String), String),
  read: fn(String) -> Result(a, Nil),
) -> Result(a, String) {
  let start = fn(body) { string.slice(body, 0, 300) }
  case answer {
    Ok(#(200, body)) ->
      read(body) |> result.replace_error("GitHub answered: " <> start(body))
    Ok(#(status, body)) ->
      Error("GitHub answered " <> int.to_string(status) <> ": " <> start(body))
    Error(reason) -> Error(reason)
  }
}

/// The standard output of git with `args`. Any failure is unexpected here.
fn git(args: List(String)) -> Result(String, Stop) {
  case run("git", args) {
    Ok(#(0, out, _)) -> Ok(out)
    Ok(#(_, out, error)) -> Error(#(CouldNotRun("git"), out <> error))
    Error(reason) -> Error(#(CouldNotRun("git"), reason))
  }
}

@external(javascript, "./node_ffi.mjs", "run")
fn run(
  program: String,
  args: List(String),
) -> Result(#(Int, String, String), String)

@external(javascript, "./node_ffi.mjs", "fetch_text")
fn fetch_text(url: String) -> Promise(Result(#(Int, String), String))

@external(javascript, "./node_ffi.mjs", "set_exit_code")
fn set_exit_code(code: Int) -> Nil
